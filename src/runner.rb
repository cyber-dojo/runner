require_relative 'file_delta'
require_relative 'string_cleaner'
require 'securerandom'
require 'find'
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
    # Readonly file-system; ensure Dir.mktmpdir is off /tmp
    # Dir.mktmpdir docs says 1st argument (prefix) must be
    # non-nil to use 2nd argument.
    Dir.mktmpdir(id, '/tmp') do |src_tmp_dir|
      write_files(src_tmp_dir, files)
      create_container(max_seconds)
      tar_pipe_in(src_tmp_dir)
      run_cyber_dojo_sh_timeout(max_seconds)
      set_colour
      Dir.mktmpdir(id, '/tmp') do |dst_tmp_dir|
        status = tar_pipe_out(dst_tmp_dir)
        if status == 0
          now_files = read_files(dst_tmp_dir + sandbox_dir)
        else
          now_files = {}
        end
        set_file_delta(files, now_files)
      end
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

  def write_files(tmp_dir, files)
    # write files to /tmp/.../sandbox on host
    tmp_dir += sandbox_dir
    shell.assert("mkdir -p #{tmp_dir}")
    files.each do |pathed_filename, file|
      content = file['content']
      sub_dir = File.dirname(pathed_filename)
      unless sub_dir == '.'
        src_dir = tmp_dir + '/' + sub_dir
        shell.assert("mkdir -p #{src_dir}")
      end
      src_filename = tmp_dir + '/' + pathed_filename
      disk.write(src_filename, content)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def sandbox_dir
    '/sandbox'
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

  def run_cyber_dojo_sh_timeout(max_seconds)
    # The [docker exec] running on the _host_ is
    # killed by Process.kill. This does _not_ kill
    # the cyber-dojo.sh running _inside_ the docker
    # container. The container is killed by the
    # docker daemon via [docker run --rm]
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    pid = Process.spawn(exec_cyber_dojo_sh_cmd, {
      pgroup:true,     # become process leader
         out:w_stdout, # redirection
         err:w_stderr  # redirection
    })
    begin
      Timeout::timeout(max_seconds) do
        _, ps = Process.waitpid2(pid)
        @status = ps.exitstatus
        @timed_out = (@status == killed_status)
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

  def killed_status
    137 # 128+9
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def exec_cyber_dojo_sh_cmd
    <<~SHELL.strip
      docker exec            `# into docker container` \
        --user=#{uid}:#{gid}                           \
        --interactive                                  \
        #{container_name}                              \
        sh -c                                          \
          '                  `# open quote`            \
          cd #{sandbox_dir}                            \
          &&                                           \
          bash ./cyber-dojo.sh                         \
          '                  `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_in(tmp_dir)
    # tar-pipe text files from /tmp on host to /sandbox in container
    #
    # All files are sent from the browser, and
    # cyber-dojo.sh cannot be deleted so there
    # must be at least one file in tmp_dir.
    #
    # [1] is for file-stamp date-time granularity
    # This relates to the modification-date (stat %y).
    # The tar --touch option is not available in a default
    # Alpine container. To add it:
    #    $ apk add --update tar
    # Also, in a default Alpine container the date-time
    # file-stamps have a granularity of one second. In other
    # words the microseconds value is always zero.
    # To add microsecond granularity:
    #    $ apk add --update coreutils
    # See the file builder/image_builder.rb on
    # https://github.com/cyber-dojo-languages/image_builder/blob/master/
    # In particular the methods
    #    o) RUN_install_tar
    #    o) RUN_install_coreutils
    #    o) RUN_install_bash
    docker_tar_pipe = <<~SHELL.strip
      cd #{tmp_dir}                                   \
      &&                                              \
      find .                 `# list tmp-dir`         \
      | sed 's|^\./||'       `# cut leading slash`    \
      | tail -n +2           `# ignore lone dot`      \
      | tar -zcf             `# create tar file`      \
           -                 `# write it to stdout`   \
           -T                `# get names to extract` \
           -                 `# from piped stdin`     \
      |                      `# pipe the tarfile`     \
        docker exec          `# into container`       \
          --user=#{uid}:#{gid}                        \
          --interactive      `# we are piping`        \
          #{container_name}                           \
          sh -c                                       \
            '                `# open quote`           \
            tar                                       \
              --touch        `# [1]`                  \
              -zxf           `# extract tar file`     \
              -              `# read from stdin`      \
              -C             `# save to the`          \
              /              `# root dir`             \
            '                `# close quote`
    SHELL
    shell.assert(docker_tar_pipe)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

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
    # and the noexec will prevent a binary or a script from running.
    # So set exec to make binaries and scripts executable.
    # Note:4 Also set ownership as default permission on docker is 755.
    # Note:5 Also limit size of tmp-fs
    "--tmpfs #{sandbox_dir}:exec,size=50M,uid=#{uid},gid=#{gid}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars
    [
      env_var('IMAGE_NAME', image_name),
      env_var('ID',         id),
      env_var('SANDBOX',    sandbox_dir)
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

  def disk
    @external.disk
  end

  def log
    @external.log
  end

  def shell
    @external.shell
  end

end

# - - - - - - - - - - - - - - - - - - - - - - - -
# The implementation of run cyber-dojo.sh is
#   o) create copies of all files in /tmp on host
#   o) one tar-pipe copies files from /tmp on hot to /sandbox in container
#   o) run cyber-dojo.sh inside the container
#   0) ...
#
# An alternative implementation is
#   o) don't create copies of files off /tmp
#   o) N tar-pipes for N files, each copying directly into the container
#   o) run cyber-dojo.sh inside the container
#
# For interests sake here's how you tar pipe without the
# intermediate /tmp files. I don't know how this would
# affect the date-time file-stamp granularity (stat %y).
#
# require 'open3'
# files.each do |name,content|
#   filename = sandbox_dir + '/' + name
#   dir = File.dirname(filename)
#   shell_cmd = "mkdir -p #{dir};"
#   shell_cmd += "cat > #{filename}"
#   shell_cmd += " && chown #{uid}:#{gid} #{filename}"
#   cmd = [
#     'docker exec',
#     '--interactive',
#     '--user=root',
#     container_name,
#     "sh -c '#{shell_cmd}'"
#   ].join(space)
#   stdout,stderr,ps = Open3.capture3(cmd, :stdin_data => content)
#   assert ps.success?
# end
# - - - - - - - - - - - - - - - - - - - - - - - -

# What ulimits are supported?
# See https://github.com/docker/go-units/blob/f2145db703495b2e525c59662db69a7344b00bb8/ulimit.go#L46-L62
