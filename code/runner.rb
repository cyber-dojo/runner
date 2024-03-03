# frozen_string_literal: true
require_relative 'capture3_with_timeout'
require_relative 'files_delta'
require_relative 'home_files'
require_relative 'sandbox'
require_relative 'tgz'
require_relative 'traffic_light'
require_relative 'utf8_clean'

class Runner
  def initialize(context)
    @context = context
    @traffic_light = TrafficLight.new(context)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(id:, files:, manifest:)
    image_name = manifest['image_name']
    return empty_result(:pulling, 'pulling', {}) unless puller.pull_image(id: id, image_name: image_name) == :pulled

    random_id = @context.random.hex8
    container_name = ['cyber_dojo_runner', id, random_id].join('_')
    command = docker_run_cyber_dojo_sh_command(id, image_name, container_name)
    max_seconds = [15, Integer(manifest['max_seconds'])].min
    files_in = Sandbox.in(files)
    tgz_in = TGZ.of(files_in.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))

    run = Capture3WithTimeout.new(@context).run(command, max_seconds, tgz_in)

    if run[:timed_out]
      threaded_docker_stop_container(id, image_name, container_name)
      log(id: id, image_name: image_name, message: 'timed_out', result: utf8_clean(run))
      timed_out_result(run)
    elsif run[:status] != 0 # See comments at end of capture3_with_timeout.rb
      log(id: id, image_name: image_name, message: 'faulty', result: utf8_clean(run))
      faulty_result(run)
    else
      colour_result(id, image_name, files_in, run[:stdout])
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Runner's requirements on image_name.
  #   o) sandbox user, uid=41966, gid=51966, home=/home/sandbox
  #   o) commands: bash, file, grep, tar, truncate
  # These are satisfied by image_name being built with
  # https://github.com/cyber-dojo-tools/image_dockerfile_augmenter

  UID = 41_966 # sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51_966 # sandbox group - runs /sandbox/cyber-dojo.sh

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  MAX_FILE_SIZE = 50 * KB # of stdout, stderr, created, changed

  STATUS = {
    pulling: 141,
    timed_out: 142,
    faulty: 143,
    gzip_error: 144
  }.freeze

  private

  include FilesDelta
  include HomeFiles

  # - - - - - - - - - - - - - - - - - - - - - -

  def threaded_docker_stop_container(id, image_name, container_name)
    # Send the stop signal, wait 1 second, send the kill signal.
    command = "docker stop --time 1 #{container_name}"
    # If [docker run] times-out then Capture3WithTimeout
    # makes process.kill() calls to kill the [docker rm] process.
    # However, this does *not* kill the *container* the
    # [docker run] initiated. Hence the [docker stop]
    @context.threader.thread('docker-stopper') do
      stdout, stderr, status = @context.sheller.capture(command)
      unless status.zero?
        log(id: id, image_name: image_name, command: command, stdout: stdout, stderr: stderr, status: status)
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def timed_out_result(run)
    empty_result(:timed_out, 'timed_out', run)
  end

  def faulty_result(run)
    empty_result(:faulty, 'faulty', run)
  end

  def colour_result(id, image_name, files_in, tgz_out)
    files_out = TGZ.files(tgz_out).each.with_object({}) do |(filename, content), memo|
      memo[filename] = truncated(content)
    end
    stdout = files_out.delete('tmp/stdout') || truncated('')
    stderr = files_out.delete('tmp/stderr') || truncated('')
    status = files_out.delete('tmp/status') || truncated('145')
    sss = [stdout['content'], stderr['content'], status['content']]
    outcome, log_info = *@traffic_light.colour(image_name, *sss)
    created, changed = files_delta(files_in, files_out)
    result(
      stdout, stderr, status['content'],
      outcome, log_info,
      Sandbox.out(at_most(16, created)),
      Sandbox.out(changed)
    )
  rescue Zlib::GzipFile::Error
    log(id: id, image_name: image_name, error: 'Zlib::GzipFile::Error')
    empty_result(:gzip_error, 'faulty', {})
  end

  def empty_result(code, outcome, log_info)
    result(
      truncated(''), truncated(''), STATUS[code].to_s,
      outcome, log_info,
      {}, {}
    )
  end

  def result(stdout, stderr, status, outcome, log, created, changed)
    {
      'stdout' => stdout, 'stderr' => stderr, 'status' => status,
      'outcome' => outcome, 'log' => log,
      'created' => created, 'changed' => changed
    }
  end

  def truncated(raw_content)
    content = Utf8.clean(raw_content)
    {
      'content' => content[0...MAX_FILE_SIZE],
      'truncated' => content.size > MAX_FILE_SIZE
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def at_most(size, new_files)
    # Limit number of created text files returned to browser.
    # NB: I tried to do this inside the run container, using
    # home_files.rb like this...
    #   function print0_filenames()
    #   {
    #     find #{sandbox_dir} -type f -print0 | head -z -n LIMIT
    #   }
    # ...but this this can exclude files such as
    # cyber-dojo.sh, makefile, hiker.h, hiker.c etc
    # which then become deleted files!
    Hash[new_files.keys.sort[0...size].map { |filename| [filename, new_files[filename]] }]
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
      ulimit('core', 0), # no core file
      ulimit('fsize', 128 * MB), # file size
      ulimit('locks', 1024), # number of file locks
      ulimit('nofile', 1024), # number of files
      ulimit('nproc', 1024), # number of processes [1]
      ulimit('stack', 16 * MB),           # stack size
      '--kernel-memory=768m',             # limited
      '--memory=768m',                    # max 768MB ram (same swap)
      '--net=none',                       # no network
      '--pids-limit=128',                 # no fork bombs
      '--security-opt=no-new-privileges' # no escalation
    ]
    # Special handling of clang/clang++'s -fsanitize=address
    options << if clang?(image_name)
                 '--cap-add=SYS_PTRACE'
               else
                 ulimit('data', 4 * GB) # data segment size
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

  def log(info)
    @context.logger.log(JSON.generate(info))
  end

  def puller
    @context.puller
  end

  SPACE = ' '
end
