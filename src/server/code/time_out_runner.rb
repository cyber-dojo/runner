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

class TimeOutRunner

  def initialize(externals, id, files, manifest)
    @externals = externals
    @id = id
    @files = files
    @manifest = manifest
    @image_name = manifest['image_name']
    @max_seconds = manifest['max_seconds']
    # Add a random-id to the container name. A container-name
    # based on _only_ the id will fail when a container with
    # that id exists and is alive. Easily possible in tests.
    # Note that remove_container() backgrounds the [docker rm].
    random_id = HEX_DIGITS.shuffle[0,8].join
    @container_name = ['cyber_dojo_runner', id, random_id].join('_')
  end

  attr_reader :id, :files, :image_name, :max_seconds, :container_name

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh
    @result = {}
    #create_container
    #begin
      run
      read_traffic_light_file
      set_traffic_light
      @result
    #ensure
    #  remove_container
    #end
  end

  private

  include FilesDelta
  include TrafficLight

  UID = 41966               # sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966               # sandbox group - runs /sandbox/cyber-dojo.sh
  SANDBOX_DIR = '/sandbox'  # where files are saved to in the container
                            # not /home/sandbox; /sandbox is fast tmp-dir
  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB
  MAX_FILE_SIZE = 50 * KB   # of stdout, stderr, created, changed

  # - - - - - - - - - - - - - - - - - - - - - -

  def run
    # prepare the output pipe
    r_stdout, w_stdout = IO.pipe
    # prepare the input pipe
    files_in = sandboxed(files)
    files_in[unrooted(MAIN_SH_PATH)] = main_sh
    r_stdin, w_stdin = IO.pipe
    w_stdin.write(into_tgz(files_in))
    w_stdin.close
    files_in.delete(unrooted(MAIN_SH_PATH))

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
      sss = { 'stdout' => packaged(''),
              'stderr' => packaged(''),
              'status' => { 'content' => '42' }
            }
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

  MAIN_SH_PATH = '/tmp/main.sh'

  def main_sh
    # [X] truncate,file
    <<~SHELL.strip
      truncate_dont_extend()
      {
        if [ $(stat -c%s "${1}") -gt #{MAX_FILE_SIZE} ]; then
          truncate --size #{MAX_FILE_SIZE+1} "${1}" # [Y]
        else
          touch "${1}"
        fi
      }
      is_truncated_text_file()
      {
        # grep -q is --quiet, we are generating text file names.
        # grep -v is --invert-match
        if file --mime-encoding ${1} | grep -qv "${1}:\\sbinary"; then
          truncate_dont_extend "${1}"
          true
        elif [ $(stat -c%s "${1}") -lt 2 ]; then
          # file incorrectly reports very small files as binary.
          true
        else
          false
        fi
      }
      unrooted()
      {
        # Tar does not like absolute pathnames so strip leading /
        echo "${1:1}"
      }
      export -f truncate_dont_extend
      export -f is_truncated_text_file
      export -f unrooted
      text_filenames()
      {
        find #{SANDBOX_DIR} -type f -exec \\
          bash -c "is_truncated_text_file {} && unrooted {}" \\;
      }

      TMP_DIR=$(mktemp -d /tmp/XXXXXX)
      STDOUT=stdout
      STDERR=stderr
      STATUS=status

      cd #{SANDBOX_DIR}
      bash ./cyber-dojo.sh \
         > "${TMP_DIR}/${STDOUT}" \
        2> "${TMP_DIR}/${STDERR}"

      echo $? > "${TMP_DIR}/${STATUS}"
      truncate_dont_extend "${TMP_DIR}/${STDOUT}"
      truncate_dont_extend "${TMP_DIR}/${STDERR}"

      TAR_FILE="${TMP_DIR}/cyber-dojo.tar"

      # -C TMP_DIR so stdout/stderr/status are NOT pathed
      tar -rf "${TAR_FILE}" -C "${TMP_DIR}" \
        "${STDOUT}" \
        "${STDERR}" \
        "${STATUS}"

      # -C / so sandbox files ARE pathed
      text_filenames | tar -C / -rf ${TAR_FILE} -T -

      gzip -c "${TAR_FILE}"
      SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_stop_command
    "docker stop --time 1 #{container_name}"
  end

  def docker_run_cyber_dojo_sh_command
    # Assumes a tgz of files on stdin. Untars this into the
    # /sandbox/ dir in the container and runs /sandbox/cyber-dojo.sh
    <<~SHELL.strip
      docker run                              \
        #{docker_run_options(image_name, id)} \
        --interactive                         \
        --name=#{container_name}              \
        #{image_name}                         \
        bash -c                               \
          '                                   \
          tar                                 \
            -C /                              \
            -zxf                              \
            -                                 \
          &&                                  \
          bash #{MAIN_SH_PATH}                \
          '
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

=begin
  def create_container
    docker_run_command = [
      'docker run',
        "--name=#{container_name}",
        docker_run_options(image_name, id),
        image_name,
          "bash -c 'sleep #{max_seconds+2}'"
    ].join(SPACE)
    # This shell.assert will catch errors in the 'outer' docker-run
    # command but not errors in the 'inner' sleep command. For example,
    # if the container has no bash [X]. Note that --detach is one of
    # the docker_run_options.
    shell.assert(docker_run_command)
  end
  # - - - - - - - - - - - - - - - - - - - - - -

  def remove_container
    # Backgrounded for a small speed-up.
    shell.exec("docker rm #{container_name} --force &")
  end
=end

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
      --init                    `# pid-1 process [2]`  \
      --rm                      `# auto rm on exit`    \
      --user=#{UID}:#{GID}      `# not root [X]`
    SHELL
  end

  # --detach                  `# later docker execs` \

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
    # container. The container is killed by remove_container()
    # with a fall-back via [docker run]'s --rm option.
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

  HEX_DIGITS = [*('a'..'z'),*('A'..'Z'),*('0'..'9')]
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
# cyber-dojo.sh's stdout/stderr are now captured inside main.sh
# This means if run() times out before cyber-dojo.sh completes
# then (currently) STDOUT/STDERR won't be catted and hence no info
# will get back to the client (except timed_out=true).
#
# I tried limiting the size of stdout/stderr "in-place" using...
# bash ./cyber-dojo.sh \
#   > >(head -c$((50*1024+1)) > "${TMP_DIR}/stdout") \
#  2> >(head -c$((50*1024+1)) > "${TMP_DIR}/stderr")
# It seems a head in a pipe can cause problems! Tests failed.
# See https://stackoverflow.com/questions/26461014
# There is already a ulimit on files.
