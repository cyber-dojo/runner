require_relative 'file_delta'
require_relative 'gzip'
require_relative 'string_cleaner'
require_relative 'tar_reader'
require_relative 'tar_writer'
require 'securerandom'
require 'timeout'

class Runner

  def initialize(external, cache)
    @external = external
    @cache = cache
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ready?
    true
  end

  def sha
    ENV['SHA']
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(image_name, id, files, max_seconds)
    @image_name = image_name
    @id = id
    run_cyber_dojo_sh_in_container(files, max_seconds)
    set_colour
    set_file_delta(files, files_now)
    {
       stdout: @stdout,
       stderr: @stderr,
       status: @status,
       colour: @colour,
      created: @created,
      deleted: @deleted,
      changed: @changed
    }
  end

  private

  attr_reader :image_name, :id

  def run_cyber_dojo_sh_in_container(files, max_seconds)
    r_stdin,  w_stdin  = IO.pipe
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe

    w_stdin.write(gzip(tar_file_writer(files).tar_file))
    w_stdin.close

    create_container(max_seconds)
    pid = Process.spawn(run_cyber_dojo_sh_command, {
      pgroup:true,     # become process leader
          in:r_stdin,  # redirection
         out:w_stdout, # redirection
         err:w_stderr  # redirection
    })
    begin
      Timeout::timeout(max_seconds) do
        _, ps = Process.waitpid2(pid)
        @status = ps.exitstatus
        @timed_out = killed?(@status)
      end
    rescue Timeout::Error
      Process_kill(pid)
      Process_detach(pid)
      @status = KILLED_STATUS
      @timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      @stdout = truncated(cleaned(max_read(r_stdout)))
      @stderr = truncated(cleaned(max_read(r_stderr)))
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh_command
    # Assumes a tgz of files is on stdin. Untars this into
    # /sandbox inside the container and runs /sandbox/cyber-dojo.sh
    #
    # [1] Ways to ensure /sandbox files have correct ownership...
    # o) untar as root; tar will try to match ownership.
    # o) untar as non-root; ownership based on the running user.
    # The latter is better:
    # o) it's faster - no need to set ownership on the source files.
    # o) it's safer - no need to run as root.
    # o) it's simpler - let the OS do it, not the tar -x
    #
    # [2] Don't use docker exec --workdir as that requires API version
    # 1.35 but CircleCI is currently using Docker Daemon API 1.32
    #
    # [3] is for file-stamp date-time granularity.
    # --touch means 'dont extract file modified time'
    # This relates to the files modification-date (stat %y).
    # Without it the untarred files may all end up with the
    # same modification date and this can break some makefiles.
    # The tar --touch option is not available in a default
    # Alpine container. To add it the image needs to run:
    #    $ apk add --update tar
    # Further, in a default Alpine container the date-time
    # file-stamps have a granularity of one second. In other
    # words the microseconds value is always zero. Again, this
    # can break some makefiles.
    # To add microsecond granularity the image also needs to run:
    #    $ apk add --update coreutils
    # Obviously, the image needs to have tar installed.
    # These image requirements are satisified by the image_builder.
    # See the file builder/image_builder.rb on
    # https://github.com/cyber-dojo-languages/image_builder/blob/master/
    # In particular the methods
    #    o) RUN_install_tar
    #    o) RUN_install_coreutils
    #    o) RUN_install_bash
    <<~SHELL.strip
      docker exec                                     \
        --interactive            `# piping stdin`     \
        --user=#{UID}:#{GID}     `# [1]`              \
        #{container_name}                             \
        bash -c                                       \
          '                      `# open quote`       \
          cd #{SANDBOX_DIR}      `# [2]`              \
          &&                                          \
          tar                                         \
            --touch              `# [3]`              \
            -zxf                 `# extract tgz file` \
            -                    `# read from stdin`  \
          &&                                          \
          bash ./cyber-dojo.sh                        \
          '                      `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # sandbox dir, user, group
  # - - - - - - - - - - - - - - - - - - - - - -

  SANDBOX_DIR = '/sandbox'
  UID = 41966
  GID = 51966

  # - - - - - - - - - - - - - - - - - - - - - -

  def files_now
    # Approval-style test-frameworks compare actual-text against
    # expected-text held inside a 'golden-master' file and, if the
    # comparison fails, generate a file holding the actual-text
    # ready for human inspection. cyber-dojo supports this by
    # returning _all_ text files (inside the container) under /sandbox
    # after cyber-dojo.sh has run.
    docker_tar_pipe = <<~SHELL.strip
      docker exec                    \
        --user=#{UID}:#{GID}         \
        #{container_name}            \
        bash -c                      \
          '      `# open quote`;     \
          #{ECHO_TEXT_FILENAMES}     \
          |                          \
          tar                        \
            -C                       \
            #{SANDBOX_DIR}           \
            -zcf `# create tgz file` \
            -    `# write to stdout` \
            -T   `# using filenames` \
            -    `# from stdin`      \
          '      `# close quote`
    SHELL
    # A crippled container (eg fork-bomb) will
    # likely not be running causing the [docker exec]
    # to fail so you cannot use shell.assert() here.
    stdout,_stderr,status = shell.exec(docker_tar_pipe)
    if status === 0
      read_tar_file(ungzip(stdout))
    else
      {}
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  ECHO_TEXT_FILENAMES =
    <<~SHELL.strip
      is_text_file() \
      { \
        `# grep -v is --invert-match`; \
        if file --mime-encoding ${1} | grep -qv "${1}:\\sbinary"; then \
          return; \
        fi; \
        `# file incorrectly reports size==0,1 as binary!`; \
        if [ $(stat -c%s "${1}") -lt 2 ]; then \
          return; \
        fi; \
        false; \
      }; \
      export -f is_text_file; \
      `# strip ./ from relative filenames; start at char 3`; \
      (cd #{SANDBOX_DIR} && find . -type f -exec \
        bash -c "is_text_file {} && echo {} | cut -c 3-" \\;)
    SHELL

  # - - - - - - - - - - - - - - - - - - - - - -
  # in-memory tar-file creation/reading
  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_file_writer(files)
    writer = TarWriter.new
    files.each do |filename,file|
      writer.write(filename, file['content'])
    end
    writer
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_tar_file(tar_file)
    reader = TarReader.new(tar_file)
    Hash[reader.files.map do |filename,content|
      # empty files are coming back as nil
      [filename, truncated(cleaned(content || ''))]
    end]
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name
    # The container-name must be unique. If the container name is
    # based on only the id then a 2nd run started while a 1st run
    # (with the same id) is still live would fail.
    @container_name ||= ['test_run_runner', id, SecureRandom.hex].join('_')
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(max_seconds)
    docker_run = [
      'docker run',
        docker_run_options,
        image_name,
          "sh -c 'sleep #{max_seconds}'"
    ].join(SPACE)
    shell.assert(docker_run)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_options
    options = <<~SHELL.strip
      #{env_vars}                                     \
      #{TMP_FS_SANDBOX_DIR}                           \
      #{TMP_FS_TMP_DIR}                               \
      #{ulimits}                                      \
      --detach                  `# later docker exec` \
      --init                    `# pid-1 process`     \
      --name=#{container_name}  `# for docker exec`   \
      --rm                      `# auto rm on exit`   \
      --user=#{UID}:#{GID}      `# not root`
    SHELL
    if clang?
      # For the -fsanitize=address option.
      options += SPACE + '--cap-add=SYS_PTRACE'
    end
    options
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars
    [
      env_var('IMAGE_NAME', image_name),
      env_var('ID',         id),
      env_var('SANDBOX',    SANDBOX_DIR)
    ].join(SPACE)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_var(name, value)
    # Note: value must not contain a single quote
    "--env CYBER_DOJO_#{name}='#{value}'"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TMP_FS_SANDBOX_DIR = "--tmpfs #{SANDBOX_DIR}:exec,size=50M,uid=#{UID},gid=#{GID}"
  # Note:1 the docker documention says --tmpfs is only available on
  # Docker for Linux. It works on DockerToolbox too (Mac).
  # Note:2 Making the sandbox dir a tmpfs should improve speed.
  # Note:3 tmp-fs's are setup as secure mountpoints.
  # If you use only '--tmpfs #{SANDBOX_DIR}'
  # then a [cat /etc/mtab] will reveal something like
  # tmpfs /sandbox tmpfs rw,nosuid,nodev,noexec,relatime,size=10240k 0 0
  #   o) rw = Mount the filesystem read-write.
  #   o) nosuid = Do not allow set-user-identifier or set-group-identifier bits to take effect.
  #   o) nodev = Do not interpret character or block special devices.
  #   o) noexec = Do not allow direct execution of any binaries.
  #   o) relatime = Update inode access times relative to modify or change time.
  # So set exec to make binaries and scripts executable.
  # Note:4 Also limit size of tmp-fs
  # Note:5 Also set ownership.

  TMP_FS_TMP_DIR = '--tmpfs /tmp:exec,size=50M'
  # May improve speed of /sandbox/cyber-dojo.sh execution.

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits
    # There is no cpu-ulimit... a cpu-ulimit of 10
    # seconds could kill a container after only 5
    # seconds... The cpu-ulimit assumes one core.
    # The host system running the docker container
    # can have multiple cores or use hyperthreading.
    # So a piece of code running on 2 cores, both 100%
    # utilized could be killed after 5 seconds.
    # What ulimits are supported?
    # See https://github.com/docker/go-units/blob/f2145db703495b2e525c59662db69a7344b00bb8/ulimit.go#L46-L62
    options = [
      ulimit('core'  ,   0   ), # core file size
      ulimit('fsize' ,  16*MB), # file size
      ulimit('locks' , 128   ), # number of file locks
      ulimit('nofile', 256   ), # number of files
      ulimit('nproc' , 128   ), # number of processes
      ulimit('stack' ,   8*MB), # stack size
      '--memory=512m',                     # max 512MB ram
      '--net=none',                        # no network
      '--pids-limit=128',                  # no fork bombs
      '--security-opt=no-new-privileges',  # no escalation
    ]
    unless clang?
      # [ulimit data] prevents clang's
      # -fsanitize=address option.
      options << ulimit('data', 4*GB) # data segment size
    end
    options.join(SPACE)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}"
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  # - - - - - - - - - - - - - - - - - - - - - -

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # difference before-after /sandbox/cyber-dojo.sh is run
  # - - - - - - - - - - - - - - - - - - - - - -

  include FileDelta

  def set_file_delta(was_files, now_files)
    if now_files === {} || @timed_out
      @created = {}
      @deleted = {}
      @changed = {}
    else
      file_delta(was_files, now_files)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # process helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  def Process_kill(pid)
    # The [docker run] process running on the _host_ is
    # killed by this Process.kill. This does _not_ kill the
    # cyber-dojo.sh process running _inside_ the docker
    # container. The container is killed by the
    # docker daemon via [docker run]'s --rm option.
    Process.kill(-KILL_SIGNAL, pid) # -ve means kill process-group
  rescue Errno::ESRCH
    # There is a race. There may no longer be a process at pid.
    # If not, you get an exception Errno::ESRCH: No such process
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def Process_detach(pid)
    # Prevents zombie child-process. Don't wait for detach status.
    Process.detach(pid)
    # There is a race. There may no longer be a process at pid.
    # If not, you don't get an exception.
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def killed?(status)
    status === KILLED_STATUS
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  KILL_SIGNAL = 9

  KILLED_STATUS = 128 + KILL_SIGNAL

  # - - - - - - - - - - - - - - - - - - - - - -
  # file content helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  include StringCleaner

  def truncated(content)
    truncate = truncate?(content)
    if truncate
      content = content[0...MAX_FILE_SIZE]
    end
    {
        'content' => content,
      'truncated' => truncate
    }
  end

  def truncate?(content)
    content.size > MAX_FILE_SIZE
  end

  MAX_FILE_SIZE = 25 * KB # Also applies to returned @stdout,@stderr.

  SPACE = ' '

  # - - - - - - - - - - - - - - - - - - - - - -
  # input helper
  # - - - - - - - - - - - - - - - - - - - - - -

  def max_read(fd)
    fd.read(MAX_FILE_SIZE + 1) || ''
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def log
    @external.log
  end

  def shell
    @external.shell
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # red-amber-green colour of stdout,stderr,status
  # - - - - - - - - - - - - - - - - - - - - - -

  def set_colour
    if @timed_out
      @colour = 'timed_out'
    else
      @colour = red_amber_green
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def red_amber_green
    rag_lambda = @cache.rag_lambda(image_name) { get_rag_lambda }
    stdout = @stdout['content']
    stderr = @stderr['content']
    colour = rag_lambda.call(stdout, stderr, @status)
    unless [:red,:amber,:green].include?(colour)
      log << rag_message(colour.to_s)
      colour = :amber
    end
    colour.to_s
  rescue => error
    log << rag_message(error.message)
    'amber'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def get_rag_lambda
    command = 'cat /usr/local/bin/red_amber_green.rb'
    docker_command = <<~SHELL.strip
      docker exec               \
        --user=#{UID}:#{GID}    \
        #{container_name}       \
          bash -c '#{command}'
    SHELL
    # In a crippled container (eg fork-bomb)
    # the shell.assert will mostly likely raise.
    catted_source = shell.assert(docker_command)
    eval(catted_source)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def rag_message(message)
    "red_amber_green lambda error mapped to :amber\n#{message}"
  end

end
