# frozen_string_literal: true
require_relative 'capture3_with_timeout'
require_relative 'files_delta'
require_relative 'home_files'
require_relative 'random_hex'
require_relative 'sandbox'
require_relative 'tgz'
require_relative 'utf8_clean'

# - - - - - - - - - - - - - - - - - - - - - - - - - - -
# [X] Runner's requirements on image_name.
# o) sandbox user, uid=41966, gid=51966, home=/home/sandbox
# o) bash, file, grep, tar, truncate
# These are satisfied by image_name being built with
# https://github.com/cyber-dojo-tools/image_builder
# https://github.com/cyber-dojo-tools/image_dockerfile_augmenter
#
# Approval-style test-frameworks compare actual-text against
# expected-text and write the actual-text to a file for human
# inspection. runner supports this by returning all text files
# under /sandbox after cyber-dojo.sh has run.
#
# If image_name is not present on the node, docker will
# attempt to pull it. The browser's kata/run_tests ajax
# call can timeout before the pull completes; this browser
# timeout is different to the Runner.run() call timing out.
# - - - - - - - - - - - - - - - - - - - - - - - - - - -

class Runner

  def initialize(externals, args)
    @externals = externals
    @id = args['id']
    @files = args['files']
    @manifest = args['manifest']
  end

  def run_cyber_dojo_sh
    files_in = Sandbox.in(files)
    tgz_in = TGZ.of(files_in.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))
    tgz_out, timed_out = *docker_run_cyber_dojo_sh(tgz_in)
    stdout,stderr,status, created,deleted,changed = *truncated_untgz(files_in, tgz_out)

    if timed_out
      log('timeout')
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
  end

  private

  include Capture3WithTimeout
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

  def docker_run_cyber_dojo_sh(tgz_in)
    container_name = [ 'cyber_dojo_runner', id, RandomHex.id(8) ].join('_')
    docker_run_command = docker_run_cyber_dojo_sh_command(container_name)
    options = {
      :stdin_data => tgz_in,
      :binmode => true,
      :timeout => max_seconds,
      :kill_after => 1
    }
    run_result = capture3_with_timeout(process, docker_run_command, options) do
      docker_stop_command = "docker stop --time 1 #{container_name}"
      stop_result = capture3_with_timeout(process, docker_stop_command, { :timeout => 4 })
      unless stop_result[:status] === 0
        # :nocov:
        log(docker_stop_command)
        # :nocov:
      end
    end
    [ run_result[:stdout], run_result[:timeout] ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def truncated_untgz(files_in, tgz_out)
    begin
      files_out = TGZ.files(tgz_out).each.with_object({}) do |(filename,content),memo|
        memo[filename] = truncated(content)
      end
      stdout = files_out.delete('stdout')
      stderr = files_out.delete('stderr')
      status = files_out.delete('status')[:content]
      created,deleted,changed = files_delta(files_in, files_out)
    rescue Zlib::GzipFile::Error
      log('Zlib::GzipFile::Error')
      stdout = truncated('')
      stderr = truncated('')
      status = '42'
      created,deleted,changed = {},{},{}
    end
    [ stdout,stderr,status, created,deleted,changed ]
  end

  def truncated(raw_content)
    content = Utf8.clean(raw_content)
    {
        content: content[0...MAX_FILE_SIZE],
      truncated: content.size > MAX_FILE_SIZE
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_cyber_dojo_sh_command(container_name)
    # --init makes container removal much faster
    <<~SHELL.strip
      docker run                                  \
      --entrypoint=""                             \
      --env CYBER_DOJO_IMAGE_NAME='#{image_name}' \
      --env CYBER_DOJO_ID='#{id}'                 \
      --env CYBER_DOJO_SANDBOX='#{Sandbox::DIR}'  \
      --init                   \
      --interactive            \
      --name=#{container_name} \
      #{TMP_FS_SANDBOX_DIR}    \
      #{TMP_FS_TMP_DIR}        \
      #{ulimits}               \
      --rm                     \
      --user=#{UID}:#{GID}     \
      #{image_name}            \
      bash -c 'tar -C / -zxf - && bash ~/main.sh'
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits
    # [1] the nproc --limit is per user across all containers. See
    # https://docs.docker.com/engine/reference/commandline/run/#set-ulimits-in-container---ulimit
    # There is no cpu-ulimit. See
    # https://github.com/cyber-dojo-retired/runner-stateless/issues/2
    options = [
      ulimit('core'  ,   0   ),           # no core file
      ulimit('fsize' ,  16*MB),           # file size
      ulimit('locks' , 1024  ),           # number of file locks
      ulimit('nofile', 1024  ),           # number of files
      ulimit('nproc' , 1024  ),           # number of processes [1]
      ulimit('stack' ,  16*MB),           # stack size
      '--kernel-memory=768m',             # limited
      '--memory=768m',                    # max 768MB ram (same swap)
      '--net=none',                       # no network
      '--pids-limit=128',                 # no fork bombs
      '--security-opt=no-new-privileges', # no escalation
    ]
    # Special handling of clang/clang++'s -fsanitize=address
    if clang?
      options << '--cap-add=SYS_PTRACE'
    else
      options << ulimit('data', 4*GB)     # data segment size
    end
    options.join(SPACE)
  end

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}"
  end

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # temporary file systems
  # - - - - - - - - - - - - - - - - - - - - - -
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
  #     - set exec to make binaries and scripts executable.
  #     - limit size of tmp-fs.
  #     - set ownership.
  # - - - - - - - - - - - - - - - - - - - - - -

  TMP_FS_SANDBOX_DIR = "--tmpfs #{Sandbox::DIR}:exec,size=50M,uid=#{UID},gid=#{GID}"
  TMP_FS_TMP_DIR     = '--tmpfs /tmp:exec,size=50M,mode=1777' # Set /tmp sticky-bit

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def log(kind)
    message = [
      "POD_NAME=#{ENV['HOSTNAME']}",
      "id=#{id}",
      "image_name=#{image_name}",
      "(#{kind})"
    ].join(', ')
    $stdout.puts(message)
    logger.write(message)
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
