# frozen_string_literal: true

require_relative 'files_delta' # files_delta(was,now)
require_relative 'gnu_unzip'   # Gnu#unzip(s)
require_relative 'gnu_zip'     # Gnu#zip(s)
require_relative 'tar_reader'  # Tar::Reader
require_relative 'tar_writer'  # Tar::Writer
require_relative 'utf8_clean'  # Utf8#clean(s)
require 'securerandom'
require 'timeout'

class Runner

  def initialize(external)
    @external = external
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
    container_name = create_container(image_name, id, max_seconds)
    command = tar_pipe_files_in_and_run_cyber_dojo_sh(container_name)
    stdout,stderr,status,timed_out = run(command, files, max_seconds)
    files_now = tar_pipe_text_files_out(container_name)
    if files_now === {} || timed_out
      created,deleted,changed = {},[],{}
    else
      created,deleted,changed = files_delta(files, files_now)
    end

    {
         stdout: stdout,
         stderr: stderr,
         status: status,
      timed_out: timed_out,
        created: created,
        deleted: deleted,
        changed: changed
    }
  end

  private

  include FilesDelta

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  SANDBOX_DIR = '/sandbox'  # where files are saved to in container
  UID = 41966               # user running /sandbox/cyber-dojo.sh
  GID = 51966               # group running /sandbox/cyber-dojo.sh
  MAX_FILE_SIZE = 50 * KB   # of stdout, stderr, created, changed

  # - - - - - - - - - - - - - - - - - - - - - -

  def run(command, files, max_seconds)
    stdout,stderr,status,timed_out = nil,nil,nil,nil
    r_stdin,  w_stdin  = IO.pipe
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    w_stdin.write(tgz(files))
    w_stdin.close
    pid = Process.spawn(command, {
      pgroup:true,     # become process leader
          in:r_stdin,  # redirection
         out:w_stdout, # redirection
         err:w_stderr  # redirection
    })
    begin
      Timeout::timeout(max_seconds) do
        _, ps = Process.waitpid2(pid)
        status = ps.exitstatus
        timed_out = killed?(status)
      end
    rescue Timeout::Error
      Process_kill_group(pid)
      Process_detach(pid)
      status = KILLED_STATUS
      timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      stdout = packaged(read_max(r_stdout))
      stderr = packaged(read_max(r_stderr))
      r_stdout.close
      r_stderr.close
    end
    [stdout,stderr,status,timed_out]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tgz(files)
    Gnu.zip(Tar::Writer.new(files).tar_file)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_max(fd)
    fd.read(MAX_FILE_SIZE + 1) || ''
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_files_in_and_run_cyber_dojo_sh(container_name)
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
    # same modification date.
    # Further, in a default Alpine container the date-time
    # file-stamps have a granularity of one second. In other
    # words the microseconds value is always zero.
    # The tar --touch option is not available
    # in a default Alpine container. To add it the image needs to run:
    #    $ apk add --update tar
    # To add microsecond granularity the image also needs to run:
    #    $ apk add --update coreutils
    # Obviously, the image also needs to have tar installed.
    # These requirements are satisified by the image_builder. See
    # https://github.com/cyber-dojo-languages/image_builder
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

  def tar_pipe_text_files_out(container_name)
    # Approval-style test-frameworks compare actual-text against
    # expected-text held inside a 'golden-master' file and, if the
    # comparison fails, generate a file holding the actual-text
    # ready for human inspection. cyber-dojo supports this by
    # returning _all_ text files (generated inside the container)
    # under /sandbox after cyber-dojo.sh has run.
    docker_tar_pipe_text_files_out = <<~SHELL.strip
      docker exec                           \
        --user=#{UID}:#{GID}                \
        #{container_name}                   \
        bash -c                             \
          '             `# open quote`;     \
          #{ECHO_TRUNCATED_TEXTFILE_NAMES}  \
          |                                 \
          tar                               \
            -C                              \
            #{SANDBOX_DIR}                  \
            -zcf        `# create tgz file` \
            -           `# write to stdout` \
            -T          `# using filenames` \
            -           `# from stdin`      \
          '             `# close quote`
    SHELL
    # A crippled container (eg fork-bomb) will
    # likely not be running causing the [docker exec]
    # to fail so you cannot use shell.assert() here.
    stdout,_stderr,status = shell.exec(docker_tar_pipe_text_files_out)
    if status === 0
      read_tar_file(Gnu.unzip(stdout))
    else
      {}
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_tar_file(tar_file)
    reader = Tar::Reader.new(tar_file)
    reader.files.each_with_object({}) do |(filename,content),memo|
      memo[filename] = packaged(content)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  # Must not contain a single-quote [bash -c '...']
  # o) grep -v is --invert-match
  # o) file incorrectly reports size==0,1 as binary
  # o) use cut -c 3- to strip ./ from relative filenames
  ECHO_TRUNCATED_TEXTFILE_NAMES =
    <<~SHELL.strip
      truncate_file() \
      { \
        if [ $(stat -c%s "${1}") -gt #{MAX_FILE_SIZE} ]; then \
          truncate -s #{MAX_FILE_SIZE+1} "${1}"; \
        fi; \
      }; \
      is_text_file() \
      { \
        if file --mime-encoding ${1} | grep -qv "${1}:\\sbinary"; then \
          truncate_file "${1}"; \
          return; \
        fi; \
        if [ $(stat -c%s "${1}") -lt 2 ]; then \
          return; \
        fi; \
        false; \
      }; \
      export -f truncate_file; \
      export -f is_text_file; \
      (cd #{SANDBOX_DIR} && find . -type f -exec \
        bash -c "is_text_file {} && echo {} | cut -c 3-" \\;)
    SHELL

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(image_name, id, max_seconds)
    # The container-name must be unique. If the container name is
    # based on _only_ the id then a 2nd run started while a 1st run
    # (with the same id) is still live would fail.
    container_name = ['cyber_dojo_runner', id, SecureRandom.hex].join('_')
    docker_run = [
      'docker run',
        "--name=#{container_name}",
        docker_run_options(image_name, id),
        image_name,
          "bash -c 'sleep #{max_seconds}'"
    ].join(SPACE)
    shell.assert(docker_run)
    container_name
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_options(image_name, id)
    options = <<~SHELL.strip
      #{env_vars(image_name, id)}                      \
      #{TMP_FS_SANDBOX_DIR}                            \
      #{TMP_FS_TMP_DIR}                                \
      #{ulimits(image_name)}                           \
      --detach                  `# later docker execs` \
      --init                    `# pid-1 process`      \
      --rm                      `# auto rm on exit`    \
      --user=#{UID}:#{GID}      `# not root`
    SHELL
    if clang?(image_name)
      # For the -fsanitize=address option.
      options += SPACE + '--cap-add=SYS_PTRACE'
    end
    options
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars(image_name, id)
    [
      env_var('IMAGE_NAME', image_name),
      env_var('ID',         id),
      env_var('SANDBOX',    SANDBOX_DIR)
    ].join(SPACE)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_var(name, value)
    # Note: value must not contain a single-quote
    "--env CYBER_DOJO_#{name}='#{value}'"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TMP_FS_SANDBOX_DIR =
    "--tmpfs #{SANDBOX_DIR}:" +
    'exec,' +       # [1]
    'size=50M,' +   # [2]
    "uid=#{UID}," + # [3]
    "gid=#{GID}"    # [3]
    # - Making the sandbox dir a tmpfs should improve speed.
    # - By default, tmp-fs's are setup as secure mountpoints.
    #    If you use only '--tmpfs #{SANDBOX_DIR}'
    #    then a [cat /etc/mtab] will reveal something like
    #    "tmpfs /sandbox tmpfs rw,nosuid,nodev,noexec,relatime,size=10240k 0 0"
    #    o) rw = Mount the filesystem read-write.
    #    o) nosuid = Do not allow set-user-identifier or
    #       set-group-identifier bits to take effect.
    #    o) nodev = Do not interpret character or block special devices.
    #    o) noexec = Do not allow direct execution of any binaries.
    #    o) relatime = Update inode access times relative to modify or change time.
    #    So...
    #     [1] set exec to make binaries and scripts executable.
    #     [2] limit size of tmp-fs.
    #     [3] set ownership.

  TMP_FS_TMP_DIR = '--tmpfs /tmp:exec,size=50M,mode=1777'
    # Set the sticky-bit on /tmp

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits(image_name)
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
    unless clang?(image_name)
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

  # - - - - - - - - - - - - - - - - - - - - - -

  def clang?(image_name)
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # process helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  def Process_kill_group(pid)
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

  def packaged(raw_content)
    content = Utf8.clean(raw_content)
    {
        'content' => truncated(content),
      'truncated' => truncate?(content)
    }
  end

  def truncated(content)
    content[0...MAX_FILE_SIZE]
  end

  def truncate?(content)
    content.size > MAX_FILE_SIZE
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def shell
    @external.shell
  end

  SPACE = ' '

end
