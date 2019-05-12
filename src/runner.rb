require_relative 'file_delta'
require_relative 'string_cleaner'
require 'find'
require 'gzipped_tar'
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
    # We do [docker run --rm --detach] so the docker daemon
    # does the [docker rm]. This means the container-name
    # must be unique. If the container name is based on just
    # the id then a 2nd run started within max_seconds of the
    # previous run (with the same id) would fail.
    # Happens a lot in tests.
    @container_name = ['test_run_runner', id, SecureRandom.hex].join('_')
    run_cyber_dojo_sh_in_container(files, max_seconds)
    set_colour
    Dir.mktmpdir(id, '/tmp') do |tmp_dir|
      status = tar_pipe_out(tmp_dir)
      if status == 0
        now_files = read_files(tmp_dir + '/' + sandbox_dirname)
      else
        now_files = {}
      end
      set_file_delta(files, now_files)
    end
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

  private # = = = = = = = = = = = = = = = = = =

  include StringCleaner

  attr_reader :image_name, :id, :container_name

  def run_cyber_dojo_sh_in_container(files, max_seconds)
    # The [docker exec] process running on the _host_ is
    # killed by Process.kill. This does _not_ kill the
    # cyber-dojo.sh process running _inside_ the docker
    # container. The container is killed by the
    # docker daemon via [docker run --rm]
    r_stdin,  w_stdin  = IO.pipe
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe

    w_stdin.write(tar_file(files))
    w_stdin.close

    create_container(max_seconds)
    pid = Process.spawn(run_cyber_dojo_sh_cmd, {
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
      Process.kill(-9, pid)   # -ve means kill process-group
      Process.detach(pid)     # prevent zombie-child but
      @status = killed_status # don't wait for detach status
      @timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      @stdout = sanitized_read(r_stdout)
      @stderr = sanitized_read(r_stderr)
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def killed?(status)
    status == killed_status
  end

  def killed_status
    128 + 9
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def tar_file(files)
    # in-memory creation of tarfile.
    writer = GZippedTar::Writer.new
    files.each do |pathed_filename, file|
      # important 1st argument does not have leading /
      writer.add(sandbox_dirname + '/' + pathed_filename, file['content'])
    end
    writer.output
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh_cmd
    # Assumes a tarfile of files is on stdin. Untars this into
    # /sandbox inside the container and runs cyber-dojo.sh
    #
    # [1] Ways to ensure /sandbox files have correct ownership...
    # o) untar as root; tar will try to match ownership.
    # o) untar as non-root; ownership based on the running user.
    # The latter is better:
    # o) it's faster - no need to set ownership on the source files.
    # o) it's safer - no need to run as root.
    # o) it's simpler - let the OS do it, not the tar -x
    #
    # [2] is for file-stamp date-time granularity.
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
    #
    # [3] Don't use docker exec --workdir as that requires API version
    # 1.35 but CircleCI is currently using Docker Daemon API 1.32
    <<~SHELL.strip
      docker exec                                     \
        --interactive            `# piping stdin`     \
        --user=#{uid}:#{gid}     `# [1]`              \
        #{container_name}                             \
        sh -c                                         \
          '                      `# open quote`       \
          tar                                         \
            --touch              `# [2]`              \
            -zxf                 `# extract tar file` \
            -                    `# read from stdin`  \
            -C                   `# save to the`      \
            /                    `# root dir`         \
          &&                                          \
          cd /#{sandbox_dirname} `# [3]`              \
          &&                                          \
          bash ./cyber-dojo.sh                        \
          '                      `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sandbox_dirname
    'sandbox'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_files(tmp_dir)
    # read files from /tmp on host
    files = {}
    Find.find(tmp_dir) do |pathed_filename|
      # eg pathed_filename =
      # '/tmp/.../features/shouty.feature
      unless File.directory?(pathed_filename)
        filename = pathed_filename[tmp_dir.size+1..-1]
        # eg filename = features/shouty.feature
        files[filename] = File.open(pathed_filename) { |fd|
          sanitized_read(fd)
        }
      end
    end
    files
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def sanitized_read(fd)
    content = fd.read(max_file_size + 1)
    if content.nil?
      content = ''
    end
    truncate = (content.size == max_file_size + 1)
    content = cleaned(content)
    if truncate
      content = content[0...max_file_size]
    end
    {
        'content' => content,
      'truncated' => truncate
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def max_file_size
      # 25K. Also applies to returned stdout/stderr.
      25 * 1024
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_out(tmp_dir)
    # tar-pipe text files from /sandbox in container to /tmp on host
    #
    # The create_text_file_tar_list.sh file is injected
    # into the test-framework image by image_builder.
    # Pass the tar-list filename as an environment
    # variable because using bash -c means you cannot
    # pass it as an argument.
    tar_list = '/tmp/tar.list'
    docker_tar_pipe = <<~SHELL.strip
      docker exec                                       \
        --user=#{uid}:#{gid}                            \
        --env TAR_LIST=#{tar_list}                      \
        #{container_name}                               \
        bash -c                                         \
          '                                             \
          /usr/local/bin/create_text_file_tar_list.sh   \
          &&                                            \
          tar -zcf - -T #{tar_list}                     \
          '                                             \
            | tar -zxf - -C #{tmp_dir}
    SHELL
    # A crippled container (eg fork-bomb) will
    # likely not be running causing the [docker exec]
    # to fail so you cannot use shell.assert() here.
    _stdout,_stderr,status = shell.exec(docker_tar_pipe)
    status
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
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    docker_cmd = <<~SHELL.strip
      docker exec               \
        --user=#{uid}:#{gid}    \
        #{container_name}       \
          bash -c '#{cmd}'
    SHELL
    # In a crippled container (eg fork-bomb)
    # the shell.assert will mostly likely raise.
    src = shell.assert(docker_cmd)
    eval(src)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def rag_message(msg)
    "red_amber_green lambda error mapped to :amber\n#{msg}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # difference between before and after cyber-dojo.sh is run
  # - - - - - - - - - - - - - - - - - - - - - -

  include FileDelta

  def set_file_delta(was_files, now_files)
    if now_files == {} || @timed_out
      @created = {}
      @deleted = {}
      @changed = {}
    else
      file_delta(was_files, now_files)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(max_seconds)
    docker_run = [
      'docker run',
        docker_run_options,
        image_name,
          "sh -c 'sleep #{max_seconds}'"
    ].join(space)
    shell.assert(docker_run)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_options
    options = <<~SHELL.strip
      #{env_vars}                                     \
      #{tmp_fs_sandbox_dir}                           \
      #{ulimits}                                      \
      --detach                  `# later docker exec` \
      --init                    `# pid-1 process`     \
      --name=#{container_name}  `# later access`      \
      --rm                      `# auto rm on exit`   \
      --user=#{uid}:#{gid}      `# not root`
    SHELL
    if clang?
      # For the -fsanitize=address option.
      options += space + '--cap-add=SYS_PTRACE'
    end
    options
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tmp_fs_sandbox_dir
    # Note:1 the docker documention says --tmpfs is only available on
    # Docker for Linux. Empirically it works on DockerToolbox (Mac) too.
    # Note:2 Making the sandbox dir a tmpfs should improve speed.
    # Note:3 tmp-fs's are setup as secure mountpoints.
    # If you use only '--tmpfs #{sandboxdir}'
    # then a [cat /etc/mtab] will reveal something like
    # tmpfs /sandbox tmpfs rw,nosuid,nodev,noexec,relatime,size=10240k 0 0
    #   o) rw = Mount the filesystem read-write.
    #   o) nosuid = Do not allow set-user-identifier or set-group-identifier bits to take effect.
    #   o) nodev = Do not interpret character or block special devices.
    #   o) noexec = Do not allow direct execution of any binaries.
    #   o) relatime = Update inode access times relative to modify or change time.
    # So set exec to make binaries and scripts executable.
    # Note:4 Also set ownership as default permission on docker is 755.
    # Note:5 Also limit size of tmp-fs
    "--tmpfs /#{sandbox_dirname}:exec,size=50M,uid=#{uid},gid=#{gid}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars
    [
      env_var('IMAGE_NAME', image_name),
      env_var('ID',         id),
      env_var('SANDBOX',    '/' + sandbox_dirname)
    ].join(space)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_var(name, value)
    # Note: value must not contain a single quote
    "--env CYBER_DOJO_#{name}='#{value}'"
  end

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
    options.join(space)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}"
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  # - - - - - - - - - - - - - - - - - - - - - -
  # sandbox user/group
  # - - - - - - - - - - - - - - - - - - - - - -

  def gid
    51966
  end

  def uid
    41966
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # misc
  # - - - - - - - - - - - - - - - - - - - - - -

  def space
    ' '
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

end
