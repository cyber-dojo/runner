# frozen_string_literal: true
require_relative 'files_delta'
require_relative 'random_hex'
require_relative 'sandbox'
require_relative 'tgz'
require_relative 'utf8_clean'
require 'timeout'

class Runner

  def initialize(externals, args)
    @externals = externals
    @id = args['id']
    @files = args['files']
    @manifest = args['manifest']
  end

  def run_cyber_dojo_sh
    files_in = Sandbox.in(files)
    container_name = create_container
    stdout,stderr,status,timed_out = *exec_cyber_dojo_sh(container_name, files_in)

    if timed_out
      created,deleted,changed = {},{},{}
      colour = ''
    else
      created,deleted,changed = *exec_text_file_changes(container_name, files_in)
      colour = traffic_light.colour(image_name, stdout[:content], stderr[:content], status)
    end

    { run_cyber_dojo_sh: {
        stdout:stdout,
        stderr:stderr,
        status:status,
        timed_out:timed_out,
        colour:colour,
        created:Sandbox.out(created),
        deleted:Sandbox.out(deleted).keys.sort,
        changed:Sandbox.out(changed),
        log:logger.log
      }
    }
  ensure
    remove_container(container_name)
  end

  private

  include FilesDelta

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  UID = 41966             # sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966             # sandbox group - runs /sandbox/cyber-dojo.sh
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

  def exec_cyber_dojo_sh(container_name, files_in)
    r_stdin,  w_stdin  = IO.pipe # into container
    r_stdout, w_stdout = IO.pipe # from container
    r_stderr, w_stderr = IO.pipe # from container
    w_stdin.write(TGZ.of(files_in))
    w_stdin.close
    options = { pgroup:true, in:r_stdin, out:w_stdout, err:w_stderr }
    command = docker_exec_cyber_dojo_sh(container_name)
    pid = process.spawn(command, options)
    timed_out = true
    status = 128+9
    begin
      Timeout::timeout(max_seconds) do
        _, ps = process.waitpid2(pid)
        timed_out = false
        status = ps.exitstatus
      end
    rescue Timeout::Error => error
      logger.write(error.class.name)
      logger.write(error.message)
      kill_process_group(pid)
    ensure
      stdout = truncated_pipe_read_close(r_stdout, w_stdout)
      stderr = truncated_pipe_read_close(r_stderr, w_stderr)
    end
    [ stdout, stderr, status, timed_out ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def truncated_pipe_read_close(r, w)
    w.close unless w.closed?
    read = truncated(r.read(MAX_FILE_SIZE + 1) || '')
    r.close
    read
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_exec_cyber_dojo_sh(container_name)
    # Assumes a tgz of files on stdin. Untars this into the
    # /sandbox/ dir ([X]) inside the container and runs
    # /sandbox/cyber-dojo.sh
    # [1] The uid/gid are for the user/group called sandbox [X].
    #     Untars files as this user to set their ownership.
    # [2] tar is installed [X].
    # [3] Don't use [docker exec --workdir] as that requires API version
    #     1.35 but CircleCI is currently using Docker Daemon API 1.32
    <<~SHELL.strip
      docker exec                                      \
        --interactive             `# piping stdin`     \
        --user=#{UID}:#{GID}      `# [1]`              \
        #{container_name}                              \
        bash -c                                        \
          '                       `# open quote`       \
          tar -C /                `# [2]`              \
            -zxf                  `# extract tgz file` \
            -                     `# read from stdin`  \
          && cd #{Sandbox::DIR}   `# [3]`              \
          && bash ./cyber-dojo.sh                      \
          '                       `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def exec_text_file_changes(container_name, files_in)
    # Approval-style test-frameworks compare actual-text against
    # expected-text held inside a 'golden-master' file and, if the
    # comparison fails, generate a file holding the actual-text
    # ready for human inspection. cyber-dojo supports this by
    # tar-piping out all text files (generated inside the container)
    # under /sandbox after cyber-dojo.sh has run.
    # [1] You must use [bash -c] on a docker exec.
    #     See https://docs.docker.com/engine/reference/commandline/exec/
    # [2] Ensure filenames are not read as tar command options.
    #     Eg -J... is a tar compression option.
    #     This option is not available on Ubuntu 16.04
    docker_tar_pipe_text_files_out =
      <<~SHELL.strip
      docker exec                                       \
        --user=#{UID}:#{GID}                            \
        #{container_name}                               \
        bash -c                     `# [1]`             \
          '                         `# open quote`      \
          ;#{ECHO_TRUNCATED_TEXTFILE_NAMES}             \
          |                                             \
          tar                                           \
            -C /                                        \
            -zcf                    `# create tgz file` \
            -                       `# write to stdout` \
            --verbatim-files-from   `# [2]`             \
            -T                      `# using filenames` \
            -                       `# from stdin`      \
          '                         `# close quote`
      SHELL
    # A crippled container (eg fork-bomb) will likely
    # not be running causing the [docker exec] to fail.
    # Be careful if you switch to bash.assert() here.
    stdout,_stderr,status = bash.exec(docker_tar_pipe_text_files_out)
    if status != 0
      return [ {}, {}, {} ]
    end
    files_out = truncated_untgz(stdout)
    files_delta(files_in, files_out)
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
  # o) Must not contain a single-quote [bash -c '...']
  # o) grep -q is --quiet
  # o) grep -v is --invert-match
  # o) Strip ./ from front of pathed filename in depathed()
  # o) The [file] utility must be installed [X]. However,
  #    it incorrectly reports very small files as binary.
  #    If size==0,1 assume its a text file.
  # o) truncates text files to MAX_FILE_SIZE+1
  #    This is so truncated?() can detect the truncation.
  #    The truncate utility must be installed [X].

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
          true; \
        elif [ $(stat -c%s "${1}") -lt 2 ]; then \
          true; \
        else \
          false; \
        fi; \
      }; \
      unrooted() \
      { \
        echo "${1:1}"; \
      }; \
      export -f truncate_file; \
      export -f is_text_file; \
      export -f unrooted; \
      (find #{Sandbox::DIR} -type f -exec \
        bash -c "is_text_file {} && unrooted {}" \\;)
    SHELL

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

  def remove_container(container_name)
    # Backgrounded for a small speed-up.
    bash.exec("docker rm #{container_name} --force &")
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
      '--memory=768m',                    # max 768MB ram
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
