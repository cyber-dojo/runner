# frozen_string_literal: true
require_relative 'files_delta'
require_relative 'gnu_zip'
require_relative 'gnu_unzip'
require_relative 'random_hex'
require_relative 'tar_reader'
require_relative 'tar_writer'
require_relative 'utf8_clean'
require 'httpray'
require 'securerandom'
require 'timeout'

class Runner

  def initialize(externals)
    @externals = externals
  end

  def alive?(_={})
    { 'alive?' => true }
  end

  def ready?(_={})
    { 'ready?' => true }
  end

  def sha(_={})
    { 'sha' => ENV['SHA'] }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :id, :files, :image_name, :max_seconds

  def run_cyber_dojo_sh(args)
    @id = args['id']
    @files = args['files']
    @image_name = args['manifest']['image_name']
    @max_seconds = args['manifest']['max_seconds']
    @result = {}
    run
    @result
  end

  private

  include FilesDelta

  UID = 41966               # [A] sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966               # [A] sandbox group - runs /sandbox/cyber-dojo.sh
  SANDBOX_DIR = '/sandbox'  # where files are saved to in the container
                            # not /home/sandbox; /sandbox is faster tmp-dir
  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB
  MAX_FILE_SIZE = 50 * KB   # of stdout, stderr, created, changed

  # - - - - - - - - - - - - - - - - - - - - - -

  def run
    files_in = sandboxed(files)
    stdout, timed_out = *docker_tar_pipe(files_in)

    begin
      #sss,files_out = *untgz(stdout)
      files_out = packaged_untgz(stdout)
      stdout = files_out.delete('stdout')
      stderr = files_out.delete('stderr')
      status = files_out.delete('status')
      created,deleted,changed = *files_delta(files_in, files_out)
    rescue Zlib::GzipFile::Error
      #sss = empty_sss
      stdout = packaged('')
      stderr = packaged('')
      status = { 'content' => '42' }
      created,deleted,changed = {},{},{}
    end

    args = []
    args << image_name
    args << stdout['content']
    args << stderr['content']
    args << status['content']
    colour = traffic_light.colour(*args)

    @result['colour'] = colour
    @result['run_cyber_dojo_sh'] = {
      stdout: stdout,
      stderr: stderr,
      status: status['content'].to_i,
      timed_out: timed_out,
      colour: colour,
      created: unsandboxed(created),
      deleted: unsandboxed(deleted).keys.sort,
      changed: unsandboxed(changed)
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_tar_pipe(files_in)
    stdout,timed_out = nil,nil

    r_stdin, w_stdin = IO.pipe   # to send tgz into container's stdin
    w_stdin.write(augmented_tgz(files_in))
    w_stdin.close

    r_stdout, w_stdout = IO.pipe # to get tgz from container's stdout
    command = docker_run_cyber_dojo_sh_command
    pid = Process.spawn(command, pgroup:true, in:r_stdin, out:w_stdout)
    begin
      Timeout::timeout(max_seconds) do # [C]
        Process.waitpid(pid)
        timed_out = false
      end
    rescue Timeout::Error
      shell.exec(docker_stop_command)
      Process_kill_group(pid)
      Process_detach(pid)
      timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      stdout = r_stdout.read
      r_stdout.close
    end
    [ stdout, timed_out ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def augmented_tgz(files)
    writer = Tar::Writer.new(files)
    writer.write(unrooted(TEXT_FILENAMES_SH_PATH), TEXT_FILENAMES_SH)
    writer.write(unrooted(MAIN_SH_PATH), MAIN_SH)
    Gnu::zip(writer.tar_file)
  end

  def packaged_untgz(tgz)
    result = {}
    reader = Tar::Reader.new(Gnu::unzip(tgz))
    reader.files.each do |filename,content|
      result[filename] = packaged(content)
    end
    result
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def sandboxed(files)
    # 'hiker.cs' ==> 'sandbox/hiker.cs'
    files.keys.each_with_object({}) do |filename,h|
      h["#{unrooted(SANDBOX_DIR)}/#{filename}"] = files[filename]
    end
  end

  def unrooted(path)
    # Tar does not like absolute pathnames so strip leading /
    path[1..-1]
  end

  def unsandboxed(files)
    # 'sandbox/hiker.cs' ==> 'hiker.cs'
    files.keys.each_with_object({}) do |filename,h|
      h[filename[SANDBOX_DIR.size..-1]] = files[filename]
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TEXT_FILENAMES_SH_PATH = '/tmp/text_filenames.sh'

  # [D] Support Approval style test frameworks.
  # [A] Dependencies: truncate,file
  # file incorrectly reports very small files as binary.
  # tar does not like absolute pathnames so strip leading /
  # grep -q is --quiet, we are generating text file names.
  # grep -v is --invert-match.
  TEXT_FILENAMES_SH =
    <<~SHELL.strip
      function text_filenames()
      {
        find #{SANDBOX_DIR} -type f -exec \\
          bash -c "is_truncated_text_file {} && unrooted {}" \\;
      }
      function is_truncated_text_file()
      {
        if file --mime-encoding ${1} | grep -qv "${1}:\\sbinary"; then
          truncate_dont_extend "${1}"
          true
        elif [ $(stat -c%s "${1}") -lt 2 ]; then
          true
        else
          false
        fi
      }
      function truncate_dont_extend()
      {
        if [ $(stat -c%s "${1}") -gt #{MAX_FILE_SIZE} ]; then
          truncate --size #{MAX_FILE_SIZE+1} "${1}" # [B]
        else
          touch "${1}"
        fi
      }
      function unrooted()
      {
        echo "${1:1}"
      }
      export -f truncate_dont_extend
      export -f is_truncated_text_file
      export -f unrooted
      SHELL

  # - - - - - - - - - - - - - - - - - - - - - -

  MAIN_SH_PATH = '/tmp/main.sh'

  # 1st tar: -C TMP_DIR so stdout/stderr/status are not pathed
  # 2nd tar: -C / so sandbox files are pathed
  # [E] See notes re adding head into cyber-dojo.sh redirect pipes.
  MAIN_SH =
    <<~SHELL.strip
      source #{TEXT_FILENAMES_SH_PATH}
      TMP_DIR=$(mktemp -d /tmp/XXXXXX)
      TAR_FILE="${TMP_DIR}/cyber-dojo.tar"
      STATUS=137 # 128+9
      trap "zip_sss; zip_sandbox; send_tgz" EXIT
      function zip_sss()
      {
        echo ${STATUS} > "${TMP_DIR}/status"
        truncate_dont_extend "${TMP_DIR}/stdout"
        truncate_dont_extend "${TMP_DIR}/stderr"
        tar -rf "${TAR_FILE}" -C "${TMP_DIR}" stdout stderr status
      }
      function zip_sandbox()
      {
        text_filenames | tar -C / -rf ${TAR_FILE} -T -
      }
      function send_tgz()
      {
        gzip -c "${TAR_FILE}"
      }
      cd #{SANDBOX_DIR}
      bash ./cyber-dojo.sh \
         > "${TMP_DIR}/stdout" \
        2> "${TMP_DIR}/stderr"
      STATUS=$?
      SHELL

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_stop_command
    "docker stop --time 1 #{container_name}"
  end

  def docker_run_cyber_dojo_sh_command
    # Assumes a tgz of files on stdin. Untars this into the
    # /sandbox/ dir in the container and runs main.sh which runs
    # /sandbox/cyber-dojo.sh
    # [1] For clang/clang++'s -fsanitize=address
    # [2] Init process also makes container removal much faster
    # [3] tar is installed and has the --touch option [A].
    #     (not true in a default Alpine)
    #     --touch means 'dont extract file modified time' (stat %y).
    #     With --touch untarred files get a 'now' modification date.
    #     However, in default Alpine, date-time file-stamps have a
    #     granularity of only 1 second. In other words, the date-time
    #     file-stamps always have a microseconds value of 000000000
    #     Alpine images are augmented [A] with a coreutils update
    #     to get non-zero microseconds.
    <<~SHELL.strip
      docker run                          \
        --cap-add=SYS_PTRACE      `# [1]` \
        #{env_vars(id, image_name)}       \
        --init                    `# [2]` \
        --interactive                     \
        --name=#{container_name}          \
        #{TMP_FS_SANDBOX_DIR}             \
        #{TMP_FS_TMP_DIR}                 \
        --rm                              \
        --user=#{UID}:#{GID}      `# [A]` \
        #{ulimits(image_name)}            \
        #{image_name}                     \
        bash -c '                         \
          tar -C / --touch -zxf - `# [3]` \
          &&                              \
          bash #{MAIN_SH_PATH}'
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars(id, image_name)
    [
      env_var('ID',         id),
      env_var('IMAGE_NAME', image_name),
      env_var('SANDBOX',    SANDBOX_DIR)
    ].join(SPACE)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_var(name, value)
    # value must not contain single-quotes
    "--env CYBER_DOJO_#{name}='#{value}'"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TMP_FS_TMP_DIR = '--tmpfs /tmp:exec,size=50M,mode=1777' # Set /tmp sticky-bit

  TMP_FS_SANDBOX_DIR =
    "--tmpfs #{SANDBOX_DIR}:" +
    'exec,' +       # [1]
    'size=50M,' +   # [2]
    "uid=#{UID}," + # [3]
    "gid=#{GID}"    # [3]
    # Making the sandbox dir a tmpfs should improve speed.
    # By default, tmp-fs's are setup as secure mountpoints.
    # If you use only '--tmpfs #{SANDBOX_DIR}'
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
    #     [3] set ownership [A]

  # - - - - - - - - - - - - - - - - - - - - - -

  def ulimits(image_name)
    # There is no cpu-ulimit... a cpu-ulimit of 10
    # seconds could kill a container after only 5
    # seconds... The cpu-ulimit assumes one core.
    # The host system running the docker container
    # can have multiple cores or use hyperthreading.
    # So a piece of code running on 2 cores, both 100%
    # utilized could be killed after 5 seconds.
    options = [
      ulimit('core'  ,   0   ),           # core file size
      ulimit('fsize' ,  16*MB),           # file size
      ulimit('locks' , 128   ),           # number of file locks
      ulimit('nofile', 256   ),           # number of files
      ulimit('nproc' , 128   ),           # number of processes
      ulimit('stack' ,   8*MB),           # stack size
      '--memory=512m',                    # max 512MB ram
      '--net=none',                       # no network
      '--pids-limit=128',                 # no fork bombs
      '--security-opt=no-new-privileges', # no escalation
    ]
    unless clang?(image_name)
      # [ulimit data] prevents clang's -fsanitize=address option.
      options << ulimit('data', 4*GB)     # data segment size
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
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name
    # Add a random-id to the container name. A container-name
    # based on _only_ the id will fail when a container with
    # that id exists and is alive. Easily possible in tests.
    @container_name ||= ['cyber_dojo_runner', id, RandomHex.id(8)].join('_')
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # process helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  KILL_SIGNAL = 9

  def Process_kill_group(pid)
    # The [docker run] process running on the _host_ is
    # killed by this Process.kill. This does _not_ kill the
    # cyber-dojo.sh process running _inside_ the docker
    # container. The container is killed by the docker-daemon
    # via [docker run]'s --rm option.
    Process.kill(-KILL_SIGNAL, pid) # -ve means kill process-group
  rescue Errno::ESRCH
    # There may no longer be a process at pid (timeout race).
    # If not, you get an exception Errno::ESRCH: No such process
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def Process_detach(pid)
    # Prevents zombie child-process. Don't wait for detach status.
    Process.detach(pid)
    # There may no longer be a process at pid (timeout race).
    # If not, you don't get an exception.
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # file content helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  def packaged(raw_content)
    content = Utf8.clean(raw_content)
    {
        'content' => truncated(content),
      'truncated' => truncated?(content)
    }
  end

  def truncated(content)
    content[0...MAX_FILE_SIZE]
  end

  def truncated?(content)
    content.size > MAX_FILE_SIZE
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def shell
    @externals.shell
  end

  def traffic_light
    @externals.traffic_light
  end

  SPACE = ' '

end

#---------------------------------------------------------------
# Notes
#
# [A] Assumes image_name was built by image_builder with a
# Dockerfile augmented by image_dockerfile_augmenter.
#   https://github.com/cyber-dojo-tools/image_builder
#   https://github.com/cyber-dojo-tools/image_dockerfile_augmenter
#
# [B] Truncate to MAX_FILE_SIZE+1 so truncated?() can detect
# and lop off the final extra byte.
#
# [C] If image_name is not present on the node, docker will
# attempt to pull it. The browser's kata/run_tests ajax
# call can timeout before the pull completes; this browser
# timeout is different to the Runner.run() call timing out.
#
# [D] Approval-style test-frameworks compare actual-text against
# expected-text held inside a 'golden-master' file and, if the
# comparison fails, generate a file holding the actual-text
# ready for human inspection. cyber-dojo supports this by
# scanning for text files (generated inside the container)
# under /sandbox after cyber-dojo.sh has run.
#
# [E] I tried limiting the size of stdout/stderr "in-place" using...
# bash ./cyber-dojo.sh \
#   > >(head -c$((50*1024+1)) > "${TMP_DIR}/stdout") \
#  2> >(head -c$((50*1024+1)) > "${TMP_DIR}/stderr")
# It seems a head in a pipe can cause problems! Tests failed.
# See https://stackoverflow.com/questions/26461014
# There is already a ulimit on files.
