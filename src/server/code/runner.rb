# frozen_string_literal: true
require_relative 'files_delta'
require_relative 'gnu_zip'
require_relative 'gnu_unzip'
require_relative 'tar_reader'
require_relative 'tar_writer'
require_relative 'traffic_light'
require_relative 'utf8_clean'
require 'securerandom'
require 'timeout'

# TODO: 1. Cache for rag-lambdas
# TODO: 2. Only gather text files if manifest['hidden_filenames'] is set

class Runner

  def initialize(externals)
    @externals = externals
  end

  def alive?(_args={})
    { 'alive?' => true }
  end

  def ready?(_args={})
    { 'ready?' => true }
  end

  def sha(_args={})
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
    read_traffic_light_file
    set_traffic_light
    @result
  end

  private

  include FilesDelta
  include TrafficLight

  UID = 41966               # [X] sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966               # [X] sandbox group - runs /sandbox/cyber-dojo.sh
  SANDBOX_DIR = '/sandbox'  # where files are saved to in the container
                            # not /home/sandbox; /sandbox is faster tmp-dir
  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB
  MAX_FILE_SIZE = 50 * KB   # of stdout, stderr, created, changed

  # - - - - - - - - - - - - - - - - - - - - - -

  def run
    # pipe for getting tgz from container on stdout
    r_stdout, w_stdout = IO.pipe
    # pipe for sending tgz into container on stdin
    files_in = sandboxed(files)
    files_in[unrooted(TEXT_FILENAMES_SH_PATH)] = TEXT_FILENAMES_SH
    files_in[unrooted(MAIN_SH_PATH)] = MAIN_SH
    r_stdin, w_stdin = IO.pipe
    w_stdin.write(into_tgz(files_in))
    w_stdin.close
    files_in.delete(unrooted(MAIN_SH_PATH))
    files_in.delete(unrooted(TEXT_FILENAMES_SH_PATH))

    stdout,timed_out = nil,nil
    command = docker_run_cyber_dojo_sh_command
    pid = Process.spawn(command, pgroup:true, in:r_stdin, out:w_stdout)
    begin
      Timeout::timeout(max_seconds) do # [Z]
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

    begin
      sss,files_out = *from_tgz(stdout)
      created,deleted,changed = *files_delta(files_in, files_out)
    rescue Zlib::GzipFile::Error
      sss = empty_sss
      created,deleted,changed = {},{},{}
    end

    @result['run_cyber_dojo_sh'] = {
      stdout: sss['stdout'],
      stderr: sss['stderr'],
      status: sss['status']['content'].to_i,
      timed_out: timed_out,
      created: unsandboxed(created),
      deleted: unsandboxed(deleted).keys.sort,
      changed: unsandboxed(changed)
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def empty_sss
    { 'stdout' => packaged(''),
      'stderr' => packaged(''),
      'status' => { 'content' => '42' }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def into_tgz(files)
    writer = Tar::Writer.new(files)
    Gnu.zip(writer.tar_file)
  end

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

  # - - - - - - - - - - - - - - - - - - - - - -

  def from_tgz(tgz)
    sss,sandbox = {},{}
    reader = Tar::Reader.new(Gnu.unzip(tgz))
    reader.files.each do |filename,content|
      if %w( stdout stderr status ).include?(filename)
        sss[filename] = packaged(content)
      else
        sandbox[filename] = packaged(content)
      end
    end
    [ sss, sandbox ]
  end

  def unsandboxed(files)
    # 'sandbox/hiker.cs' ==> 'hiker.cs'
    files.keys.each_with_object({}) do |filename,h|
      h[filename[SANDBOX_DIR.size..-1]] = files[filename]
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TEXT_FILENAMES_SH_PATH = '/tmp/text_filenames.sh'

  # [X] truncate,file
  # grep -q is --quiet, we are generating text file names.
  # grep -v is --invert-match.
  # file incorrectly reports very small files as binary.
  # tar does not like absolute pathnames so strip leading /
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
          truncate --size #{MAX_FILE_SIZE+1} "${1}" # [Y]
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
  MAIN_SH =
    <<~SHELL.strip
      source #{TEXT_FILENAMES_SH_PATH}
      TMP_DIR=$(mktemp -d /tmp/XXXXXX)
      TAR_FILE="${TMP_DIR}/cyber-dojo.tar"
      STATUS=137 # 128+9
      trap cyber_done EXIT
      function cyber_done() { zip_sss; zip_sandbox; send_tgz; }
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
    # /sandbox/ dir in the container and runs /sandbox/cyber-dojo.sh
    # [1] For clang/clang++'s -fsanitize=address
    # [2] Makes container removal much faster
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
        --user=#{UID}:#{GID}      `# [X]` \
        #{ulimits(image_name)}            \
        #{image_name}                     \
        bash -c '                         \
          tar -C / -zxf -                 \
          &&                              \
          bash #{MAIN_SH_PATH}'
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_traffic_light_file
    docker_cat_rag_file =
      <<~SHELL.strip
      docker run              \
        --entrypoint=cat      \
        --rm                  \
        --user=#{UID}:#{GID}  \
        #{image_name}         \
        /usr/local/bin/red_amber_green.rb
      SHELL

    stdout,stderr,status = shell.exec(docker_cat_rag_file)
    if status === 0
      rag_src = stdout
    else
      @result['diagnostic'] = { 'stderr' => stderr }
      rag_src = nil
    end
    @result['rag_src'] = rag_src
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name
    # Add a random-id to the container name. A container-name
    # based on _only_ the id will fail when a container with
    # that id exists and is alive. Easily possible in tests.
    @container_name ||= ['cyber_dojo_runner', id, random_id].join('_')
  end

  def random_id
    HEX_DIGITS.shuffle[0,8].join
  end

  HEX_DIGITS = [*('a'..'z'),*('A'..'Z'),*('0'..'9')]

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
    #     [3] set ownership [X]

  TMP_FS_TMP_DIR = '--tmpfs /tmp:exec,size=50M,mode=1777' # Set /tmp sticky-bit

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

  SPACE = ' '

end

#---------------------------------------------------------------
# Notes
#
# [X] Assumes image_name was built by image_builder with a
# Dockerfile augmented by image_dockerfile_augmenter.
#   https://github.com/cyber-dojo-tools/image_builder
#   https://github.com/cyber-dojo-tools/image_dockerfile_augmenter
#
# [Y] Truncate to MAX_FILE_SIZE+1 so truncated?() can detect
# and lop off the final extra byte.
#
# [Z] If image_name is not present on the node, docker will
# attempt to pull it. The browser's kata/run_tests ajax
# call can timeout before the pull completes; this browser
# timeout is different to the Runner.run() call timing out.
#
# Approval-style test-frameworks compare actual-text against
# expected-text held inside a 'golden-master' file and, if the
# comparison fails, generate a file holding the actual-text
# ready for human inspection. cyber-dojo supports this by
# scanning for text files (generated inside the container)
# under /sandbox after cyber-dojo.sh has run.
#
# I tried limiting the size of stdout/stderr "in-place" using...
# bash ./cyber-dojo.sh \
#   > >(head -c$((50*1024+1)) > "${TMP_DIR}/stdout") \
#  2> >(head -c$((50*1024+1)) > "${TMP_DIR}/stderr")
# It seems a head in a pipe can cause problems! Tests failed.
# See https://stackoverflow.com/questions/26461014
# There is already a ulimit on files.
