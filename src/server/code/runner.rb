# frozen_string_literal: true
require_relative 'files_delta'
require_relative 'home_files'
require_relative 'random_hex'
require_relative 'sandbox'
require_relative 'tgz'
require_relative 'utf8_clean'
require 'timeout'

# - - - - - - - - - - - - - - - - - - - - - - - - - - -
# [X] Runner's requirements on image_name.
# o) sandbox user, uid=41966, gid=51966, home=/home/sandbox
# o) bash, file, grep, tar, truncate
# These are satisfied by image_name being built with
# https://github.com/cyber-dojo-tools/image_builder
# https://github.com/cyber-dojo-tools/image_dockerfile_augmenter
#
# If image_name is not present on the node, docker will
# attempt to pull it. The browser's kata/run_tests ajax
# call can timeout before the pull completes; this browser
# timeout is different to the Runner.run() call timing out.
#
# Approval-style test-frameworks compare actual-text against
# expected-text held inside a 'golden-master' file and, if the
# comparison fails, generate a file holding the actual-text
# for human inspection. runner supports this by returning
# all text files under /sandbox after cyber-dojo.sh has run.
# - - - - - - - - - - - - - - - - - - - - - - - - - - -

class Runner

  def initialize(externals, args)
    @externals = externals
    @id = args['id']
    @files = args['files']
    @manifest = args['manifest']
  end

  def run_cyber_dojo_sh
    container_name = create_container
    files_in = Sandbox.in(files)
    tgz_in = TGZ.of(files_in.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))
    tgz_out, timed_out = *exec_cyber_dojo_sh(container_name, tgz_in)
    begin
      files_out = truncated_untgz(tgz_out)
      stdout = files_out.delete('stdout')
      stderr = files_out.delete('stderr')
      status = files_out.delete('status')[:content]
      created,deleted,changed = files_delta(files_in, files_out)
    rescue Zlib::GzipFile::Error
      stdout = truncated('')
      stderr = truncated('')
      status = '42'
      created,deleted,changed = {},{},{}
    end

    if timed_out
      colour = ''
    else
      colour = traffic_light.colour(image_name, stdout[:content], stderr[:content], status)
    end

    { run_cyber_dojo_sh: {
         stdout: stdout,
         stderr: stderr,
         status: status,
      timed_out: timed_out,
         colour: colour,
        created: Sandbox.out(created),
        deleted: Sandbox.out(deleted).keys.sort,
        changed: Sandbox.out(changed),
            log: logger.log
      }
    }
  ensure
    remove_container(container_name)
  end

  private

  include FilesDelta
  include HomeFiles

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  UID = 41966             # [X] sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966             # [X] sandbox group - runs /sandbox/cyber-dojo.sh
  MAX_FILE_SIZE = 50 * KB # of stdout, stderr, created, changed

  # - - - - - - - - - - - - - - - - - - - - - -
  # properties

  attr_reader :id, :files

  def image_name
    @manifest['image_name']
  end

  def max_seconds
    @manifest['max_seconds']
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def exec_cyber_dojo_sh(container_name, tgz_in)
    r_stdin,  w_stdin  = IO.pipe
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe 
    w_stdin.write(tgz_in)
    w_stdin.close
    options = { pgroup:true, in:r_stdin, out:w_stdout, err:w_stderr }
    command = docker_exec_cyber_dojo_sh(container_name)
    pid = process.spawn(command, options)
    timed_out = true
    begin
      Timeout::timeout(max_seconds) do
        _, _ps = process.waitpid2(pid)
        timed_out = false
      end
    rescue Timeout::Error => error
      #stop_container(container_name)
      message = "POD_NAME=#{ENV['HOSTNAME']}, id=#{id}, image_name=#{image_name}"
      $stdout.puts(message)
      logger.write(message)
      logger.write(error.message)
      kill_process_group(pid)
    ensure
      tgz_out = pipe_read_close(r_stdout, w_stdout)
      stderr = truncated_pipe_read_close(r_stderr, w_stderr)
    end
    logger.write(stderr[:content])
    [ tgz_out, timed_out ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def pipe_read_close(r, w)
    w.close unless w.closed?
    bytes = r.read
    r.close
    bytes
  end

  def truncated_pipe_read_close(r, w)
    w.close unless w.closed?
    read = truncated(r.read(MAX_FILE_SIZE + 1) || '')
    r.close
    read
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_exec_cyber_dojo_sh(container_name)
    # Assumes a tgz of files on stdin.
    <<~SHELL.strip
      docker exec                                      \
        --interactive             `# piping stdin`     \
        --user=#{UID}:#{GID}      `# [X]`              \
        #{container_name}                              \
        bash -c                                        \
          '                       `# open quote`       \
          tar -C /                `# [X]`              \
            -zxf                  `# extract tgz file` \
            -                     `# read from stdin`  \
          && bash ~/main.sh                            \
          '                       `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def truncated_untgz(tgz)
    TGZ.files(tgz).each.with_object({}) do |(filename,content),memo|
      memo[filename] = truncated(content)
    end
  end

  def truncated(raw_content)
    content = Utf8.clean(raw_content)
    {
        content: content[0...MAX_FILE_SIZE],
      truncated: content.size > MAX_FILE_SIZE
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container
    # Add a random-id to the container name. A container-name
    # based on _only_ the id will fail when a container with
    # that id already exists.
    container_name = ['cyber_dojo_runner', id, RandomHex.id(8)].join('_')
    docker_run_command = [
      'docker run',
        '--entrypoint=""',
        "--name=#{container_name}",
        docker_run_options(image_name, id),
        image_name,
          "bash -c 'sleep #{max_seconds+2}'"
    ].join(SPACE)
    # This bash.assert will catch errors in the 'outer' docker-run
    # command but not errors in the 'inner' sleep command. For example,
    # if the container has no bash [X]. Note that --detach is one of
    # the docker_run_options.
    bash.assert(docker_run_command)
    container_name
  end

  #def stop_container(container_name)
  #  stdout,stderr,status = bash.exec("docker stop --time 1 #{container_name}")
  #  p "docker stop --time 1 #{container_name}"
  #  p "stdout:#{stdout}:"
  #  p "stderr:#{stderr}:"
  #  p "status:#{status}:"
  #end

  def remove_container(container_name)
    bash.exec("docker rm --force #{container_name} &")
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_options(image_name, id)
    # [1] For clang/clang++'s -fsanitize=address
    # [2] Makes container removal much faster
    <<~SHELL.strip
      #{env_vars(image_name, id)}                      \
      #{TMP_FS_SANDBOX_DIR}                            \
      #{TMP_FS_TMP_DIR}                                \
      #{ulimits(image_name)}                           \
      --cap-add=SYS_PTRACE      `# [1]`                \
      --detach                  `# later docker execs` \
      --init                    `# pid-1 process [2]`  \
      --rm                      `# auto rm on exit`    \
      --user=#{UID}:#{GID}      `# not root`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars(image_name, id)
    [
      env_var('IMAGE_NAME', image_name),
      env_var('ID',         id),
      env_var('SANDBOX',    Sandbox::DIR)
    ].join(SPACE)
  end

  def env_var(name, value)
    # Note: value must not contain a single-quote
    "--env CYBER_DOJO_#{name}='#{value}'"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits(image_name)
    # There is no cpu-ulimit. See
    # https://github.com/cyber-dojo-retired/runner-stateless/issues/2
    options = [
      ulimit('core'  ,   0   ),           # no core file
      ulimit('fsize' ,  16*MB),           # file size
      ulimit('locks' , 128   ),           # number of file locks
      ulimit('nofile', 256   ),           # number of files
      ulimit('nproc' , 128   ),           # number of processes
      ulimit('stack' ,   8*MB),           # stack size
      '--memory=768m',                    # max 768MB ram, same swap
      '--net=none',                       # no network
      '--pids-limit=128',                 # no fork bombs
      '--security-opt=no-new-privileges', # no escalation
    ]
    unless clang?(image_name)
      # [ulimit data] prevents clang's
      # -fsanitize=address option.
      options << ulimit('data', 4*GB)     # data segment size
    end
    options.join(SPACE)
  end

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}"
  end

  def clang?(image_name)
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # temporary file systems
  # - - - - - - - - - - - - - - - - - - - - - -

  TMP_FS_TMP_DIR = '--tmpfs /tmp:exec,size=50M,mode=1777' # Set /tmp sticky-bit

  TMP_FS_SANDBOX_DIR =
  [
    "--tmpfs #{Sandbox::DIR}:",
    'exec,',                 # [1]
    'size=50M,',             # [2]
    "uid=#{UID},gid=#{GID}"  # [3]
  ].join
    # Making the sandbox dir a tmpfs should improve speed.
    # By default, tmp-fs's are setup as secure mountpoints.
    # If you use only '--tmpfs #{Sandbox::DIR}'
    # then a [cat /etc/mtab] will reveal something like
    # "tmpfs /sandbox tmpfs rw,nosuid,nodev,noexec,relatime,size=10240k 0 0"
    #   o) rw = Mount the filesystem read-write.
    #   o) nosuid = Do not allow set-user-identifier or
    #      set-group-identifier bits to take effect.
    #   o) nodev = Do not interpret character or block special devices.
    #   o) noexec = Do not allow direct execution of any binaries.
    #   o) relatime = Update inode access times relative to modify/change time.
    #   So...
    #     [1] set exec to make binaries and scripts executable.
    #     [2] limit size of tmp-fs.
    #     [3] set ownership.

  # - - - - - - - - - - - - - - - - - - - - - -
  # process
  # - - - - - - - - - - - - - - - - - - - - - -
  # Kill the [docker run] process running on the host.
  # This does not kill the docker container.
  # The docker container is killed by
  # o) the --rm option to [docker run]
  # o) the [docker stop --time 1] if there is a timeout.
  # - - - - - - - - - - - - - - - - - - - - - -

  def kill_process_group(pid)
    # Kill the [docker run]. There is a
    # timeout race here; there might not
    # be a process at pid any longer.
    process.kill(:KILL, -pid)
  rescue Errno::ESRCH => error
    # :nocov:
    logger.write(error.message)
    # :nocov:
    # We lost the race. Nothing to do.
  ensure
    # Prevent zombie child-process.
    # Don't wait for detach status.
    # No exception if we lost the race.
    process.detach(pid)
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def bash
    @externals.bash
  end

  def logger
    @externals.logger
  end

  def process
    @externals.process
  end

  def traffic_light
    @externals.traffic_light
  end

  SPACE = ' '

end
