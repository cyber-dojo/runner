# frozen_string_literal: true
require_relative 'capture3_with_timeout'
require_relative 'files_delta'
require_relative 'home_files'
require_relative 'random_hex'
require_relative 'sandbox'
require_relative 'tgz'
require_relative 'traffic_light'
require_relative 'utf8_clean'

class Runner

  def initialize(context)
    # Comments marked [X] are expanded at the end of this file.
    @context = context
    @traffic_light = TrafficLight.new(context)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(id:, files:, manifest:)
    image_name = manifest['image_name']
    max_seconds = manifest['max_seconds']
    files_in = Sandbox.in(files)
    tgz_in = TGZ.of(files_in.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))

    result = docker_run_cyber_dojo_sh(id, image_name, max_seconds, tgz_in)

    if result[:timed_out]
      stdout,stderr,status, created,deleted,changed = dummy_result(142)
      colour,log_info = '', result
      log(id:id, image_name:image_name, message:'timed_out', result:utf8_clean(result))
    elsif result[:status] != 0
      stdout,stderr,status, created,deleted,changed = dummy_result(143)
      colour,log_info = 'faulty',result
      log(id:id, image_name:image_name, message:'faulty', result:utf8_clean(result))
    else
      tgz_out = result[:stdout]
      stdout,stderr,status, created,deleted,changed = *truncated_untgz(id, image_name, files_in, tgz_out)
      sss = [ stdout[:content], stderr[:content], status[:content] ]
      colour,log_info = *@traffic_light.colour(image_name, *sss)
    end

    {
         stdout: stdout,
         stderr: stderr,
         status: status[:content],
      timed_out: result[:timed_out],
         colour: colour,
        created: Sandbox.out(created),
        deleted: Sandbox.out(deleted).keys.sort,
        changed: Sandbox.out(changed),
            log: log_info
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

  def dummy_result(n)
    stdout = truncated('')
    stderr = truncated('')
    status = truncated(n.to_s)
    created,deleted,changed = {},{},{}
    [ stdout,stderr,status, created,deleted,changed ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_cyber_dojo_sh(id, image_name, max_seconds, tgz_in)
    container_name = [ 'cyber_dojo_runner', id, RandomHex.id(8) ].join('_')
    command = docker_run_cyber_dojo_sh_command(id, image_name, container_name)
    spawn_opts = {
      :binmode => true,
      :kill_after => 1,
      :pgroup => true,
      :stdin_data => tgz_in,
      :timeout => max_seconds
    }
    capture3_with_timeout(@context, command, spawn_opts) do
      # The [docker run] command timed-out.
      docker_stop_container(id, image_name, container_name)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_stop_container(id, image_name, container_name)
    # If the container is running, stop it.
    # Note: I have tried using the [docker run] --stop-timeout option
    # instead of using capture3_with_timeout().
    # In tests, it fails to stop a container in an infinite loop.
    command = "docker stop --time 1 #{container_name}"
    options = { timeout:4 }
    result = capture3_with_timeout(@context, command, options)
    unless result[:status] === 0
      # :nocov:
      log(id:id, image_name:image_name, command:command)
      # :nocov:
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def truncated_untgz(id, image_name, files_in, tgz_out)
    begin
      files_out = TGZ.files(tgz_out).each.with_object({}) do |(filename,content),memo|
        memo[filename] = truncated(content)
      end
      stdout = files_out.delete('stdout') || truncated('')
      stderr = files_out.delete('stderr') || truncated('')
      status = files_out.delete('status') || truncated('142')
      created,deleted,changed = files_delta(files_in, files_out)
    rescue Zlib::GzipFile::Error
      log(id:id, image_name:image_name, error:'Zlib::GzipFile::Error')
      stdout = truncated('')
      stderr = truncated('')
      status = truncated('142')
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

  def docker_run_cyber_dojo_sh_command(id, image_name, container_name)
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
      #{ulimits(image_name)}   \
      --rm                     \
      --user=#{UID}:#{GID}     \
      #{image_name}            \
      bash -c 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits(image_name)
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
    if clang?(image_name)
      options << '--cap-add=SYS_PTRACE'
    else
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

  def utf8_clean(result)
    result[:stdout] = Utf8.clean(result[:stdout])
    result[:stderr] = Utf8.clean(result[:stderr])
  end

  def log(properties)
    @context.logger.log(JSON.pretty_generate(properties))
  end

  SPACE = ' '

end

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
# Note: The browser's kata/run_tests ajax call timeout is
# different to the Runner.run() call timing out.
# - - - - - - - - - - - - - - - - - - - - - - - - - - -
