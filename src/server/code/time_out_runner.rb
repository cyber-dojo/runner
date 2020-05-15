# frozen_string_literal: true
require_relative 'files_delta'
require_relative 'gnu_unzip'
require_relative 'gnu_zip'
require_relative 'tar_reader'
require_relative 'tar_writer'
require_relative 'traffic_light'
require_relative 'utf8_clean'
require 'securerandom'
require 'timeout'

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

class TimeOutRunner

  def initialize(externals, id, files, manifest)
    @externals = externals
    @id = id
    @files = files
    # Add a random-id to the container name. A container-name
    # based on _only_ the id will fail when a container with
    # that id exists and is alive. Easily possible in tests.
    # Note that remove_container() backgrounds the [docker rm].
    random_id = HEX_DIGITS.shuffle[0,8].join
    @container_name = ['cyber_dojo_runner', id, random_id].join('_')
    @manifest = manifest
  end

  attr_reader :id, :files, :container_name

  def image_name
    @manifest['image_name']
  end

  def max_seconds
    @manifest['max_seconds']
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh
    @result = {}
    create_container
    begin
      run
      read_text_file_changes
      set_traffic_light
      @result
    ensure
      remove_container
    end
  end

  private

  include FilesDelta
  include TrafficLight

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  SANDBOX_DIR = '/sandbox'  # where files are saved to in the container
  UID = 41966               # sandbox user  - runs /sandbox/cyber-dojo.sh
  GID = 51966               # sandbox group - runs /sandbox/cyber-dojo.sh

  MAX_FILE_SIZE = 50 * KB   # of stdout, stderr, created, changed

  HEX_DIGITS = [*('a'..'z'),*('A'..'Z'),*('0'..'9')]

  # - - - - - - - - - - - - - - - - - - - - - -

  def run
    command = main_docker_run_command
    stdout,stderr,status,timed_out = nil,nil,nil,nil
    r_stdin,  w_stdin  = IO.pipe
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    w_stdin.write(tgz_of_files)
    w_stdin.close
    pid = Process.spawn(command, {
      pgroup:true,     # become process leader
          in:r_stdin,  # redirection
         out:w_stdout, # redirection
         err:w_stderr  # redirection
    })
    begin
      Timeout::timeout(max_seconds) do # [Z]
        _, ps = Process.waitpid2(pid)
        status = ps.exitstatus
        timed_out = killed?(status)
      end
    rescue Timeout::Error
      Process_kill_group(pid)
      Process_detach(pid)
      status = KILLED_STATUS
      timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      stdout = packaged(read_max(r_stdout))
      stderr = packaged(read_max(r_stderr))
      r_stdout.close
      r_stderr.close
    end
    @result['run_cyber_dojo_sh'] = {
      stdout:stdout,
      stderr:stderr,
      status:status,
      timed_out:timed_out
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tgz_of_files
    writer = Tar::Writer.new(sandboxed(files))
    writer.write(unrooted(MAIN_SH_PATH), main_sh)
    writer.write(unrooted(TRUNCATED_TEXTFILE_NAMES_SH_PATH), TRUNCATED_TEXTFILE_NAMES_SH)
    Gnu.zip(writer.tar_file)
  end

  def sandboxed(files)
    files.keys.each_with_object({}) do |filename,h|
      h["#{unrooted(SANDBOX_DIR)}/#{filename}"] = files[filename]
    end
  end

  def unrooted(path)
    # Pathnames with a leading / give tar warnings:
    # tar: Removing leading `/' from member names
    # So strip off leading /
    path[1..-1]
  end

  MAIN_SH_PATH = '/tmp/main.sh'

  def main_sh
    # I tried limiting the size of stdout/stderr "in-place" using...
    # bash ./cyber-dojo.sh \
    #   > >(head -c$((50*1024+1)) > "${TMP_DIR}/stdout") \
    #  2> >(head -c$((50*1024+1)) > "${TMP_DIR}/stderr")
    # It seems a head in a pipe can cause problems! Tests failed.
    # See https://stackoverflow.com/questions/26461014
    # There is already a ulimit on files.
    <<~SHELL.strip
      TMP_DIR=$(mktemp -d /tmp/XXXXXX)
      STDOUT="${TMP_DIR}/stdout"
      STDERR="${TMP_DIR}/stderr"
      cd #{SANDBOX_DIR}
      bash ./cyber-dojo.sh > "${STDOUT}" 2> "${STDERR}"
      STATUS=$?
      truncate_dont_extend() # [X][Y]
      {
        filename="${1}"
        if [ $(stat -c%s "${filename}") -gt #{MAX_FILE_SIZE} ]; then
          truncate --size #{MAX_FILE_SIZE+1} "${filename}"
        fi
      }
      if [ -f ${STDOUT} ]; then
        truncate_dont_extend "${STDOUT}"
        cat "${STDOUT}"
      fi
      if [ -f "${STDERR}" ]; then
        truncate_dont_extend "${STDERR}"
        cat "${STDERR}" 1>&2
      fi
      exit ${STATUS}
      SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_max(fd)
    fd.read(MAX_FILE_SIZE + 1) || ''
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def main_docker_run_command
    # Assumes a tgz of files on stdin. Untars this into the
    # /sandbox/ dir (which must exist [X]) inside the container
    # and runs /sandbox/cyber-dojo.sh
    #
    # [1] The uid/gid are for the user/group called sandbox [X].
    #     Untars files as this user to set their ownership.
    # [2] tar is installed [X].
    # [3] tar has the --touch option installed [X].
    #     (not true in a default Alpine container)
    #     --touch means 'dont extract file modified time'
    #     It relates to the files modification-date (stat %y).
    #     Without it the untarred files may all end up with the same
    #     modification date. With it, the untarred files have a
    #     proper date-time file-stamp in all supported OS's.
    # [4] tar date-time file-stamps have a granularity < 1 second [X].
    #     In a default Alpine container the date-time file-stamps
    #     have a granularity of one second; viz, the microseconds
    #     value is always zero.
    # [5] Don't use [docker exec --workdir] as that requires API version
    #     1.35 but CircleCI is currently using Docker Daemon API 1.32
    <<~SHELL.strip
      docker exec                                     \
        --interactive            `# piping stdin`     \
        --user=#{UID}:#{GID}     `# [1]`              \
        #{container_name}                             \
        bash -c                                       \
          '                      `# open quote`       \
          cd /                                        \
          &&                                          \
          tar                    `# [2]`              \
            --touch              `# [3][4]`           \
            -zxf                 `# extract tgz file` \
            -                    `# read from stdin`  \
          &&                                          \
          bash /tmp/main.sh      `# [5]`              \
          '                      `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_text_file_changes
    # Approval-style test-frameworks compare actual-text against
    # expected-text held inside a 'golden-master' file and, if the
    # comparison fails, generate a file holding the actual-text
    # ready for human inspection. cyber-dojo supports this by
    # tar-piping out all text files (generated inside the container)
    # under /sandbox after cyber-dojo.sh has run.
    #
    # [1] Extract /usr/local/bin/red_amber_green.rb if it exists.
    # [2] Ensure filenames are not read as tar command options.
    #     Eg -J... is a tar compression option.
    #     This option is not available on Ubuntu 16.04
    rag_filename = SecureRandom.urlsafe_base64
    docker_tar_pipe_text_files_out =
      <<~SHELL.strip
      docker exec                                        \
        --user=#{UID}:#{GID}                             \
        #{container_name}                                \
        bash -c                                          \
          '                          `# open quote`      \
          #{copy_rag(rag_filename)}; `# [1]`             \
          source /tmp/echo_truncated_textfilenames.sh    \
          |                                              \
          tar                                            \
            -C                                           \
            #{SANDBOX_DIR}                               \
            -zcf                     `# create tgz file` \
            -                        `# write to stdout` \
            --verbatim-files-from    `# [2]`             \
            -T                       `# using filenames` \
            -                        `# from stdin`      \
          '                          `# close quote`
      SHELL
    # A crippled container (eg fork-bomb) will likely
    # not be running causing the [docker exec] to fail.
    # Be careful if you switch to shell.assert() here.
    stdout,stderr,status = shell.exec(docker_tar_pipe_text_files_out)
    if status === 0
      files_now = read_tar_file(Gnu.unzip(stdout))
      rag_src = extract_rag(files_now, rag_filename)
      created,deleted,changed = *files_delta(files, files_now)
    else
      @result['diagnostic'] = { 'stderr' => stderr }
      rag_src = nil
      created,deleted,changed = {}, [], {}
    end
    @result['rag_src'] = rag_src
    @result['run_cyber_dojo_sh'].merge!({
      created:created,
      deleted:deleted,
      changed:changed
    })
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def copy_rag(rag_filename)
    rag_src = '/usr/local/bin/red_amber_green.rb'
    rag_dst = "#{SANDBOX_DIR}/#{rag_filename}"
    # This command must not write anything to stdout/stderr
    # since it would be taken as a filename by tar's -T option.
    "[ -f #{rag_src} ] && cp #{rag_src} #{rag_dst}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def extract_rag(files_now, rag_filename)
    rag_file = files_now.delete(rag_filename)
    if rag_file.nil?
      nil
    else
      rag_file['content']
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def read_tar_file(tar_file)
    reader = Tar::Reader.new(tar_file)
    reader.files.each_with_object({}) do |(filename,content),memo|
      memo[filename] = packaged(content)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  TRUNCATED_TEXTFILE_NAMES_SH_PATH = '/tmp/echo_truncated_textfilenames.sh'

  TRUNCATED_TEXTFILE_NAMES_SH =
    # file [X]
    #   incorrectly reports very small files as binary.
    #   if size==0,1 assume its a text file.
    # grep
    #   -q is --quiet, we are generating text file names.
    #   -v is --invert-match
    # unrooted
    #   strip ./ from front of pathed filename ready for tar to read
    <<~SHELL.strip
      truncate_dont_extend() # [X][Y]
      {
        if [ $(stat -c%s "${1}") -gt #{MAX_FILE_SIZE} ]; then
          truncate --size=#{MAX_FILE_SIZE+1} "${1}" # [Y]
        fi
      }
      is_text_file()
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
      unrooted()
      {
        echo "${1:2}"
      }
      export -f truncate_dont_extend
      export -f is_text_file
      export -f unrooted
      (cd #{SANDBOX_DIR} && find . -type f -exec \
        bash -c "is_text_file {} && unrooted {}" \\;)
    SHELL

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

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
    #     [3] set ownership.

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

  def killed?(status)
    status === KILLED_STATUS
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  KILL_SIGNAL = 9

  KILLED_STATUS = 128 + KILL_SIGNAL

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
