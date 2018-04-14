require_relative 'all_avatars_names'
require_relative 'shell'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require 'timeout'
require 'find'

class Runner # stateless

  def initialize(external, image_name, kata_id)
    @disk = external.disk
    @shell = Shell.new(external)
    @image_name = image_name
    @kata_id = kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?
    command = 'docker images --format "{{.Repository}}"'
    shell.assert(command).split("\n").include?(image_name)
  end

  def image_pull
     # [1] stderr varies depending on the host's Docker version
    command = "docker pull #{image_name}"
    stdout,stderr,status = shell.exec(command)
    if status == shell.success
      return true
    elsif stderr.include?('not found') || stderr.include?('not exist')
      return false # [1]
    else
      raise ShellError.new(stderr, {
        command:command,
         stdout:stdout,
         stderr:stderr,
         status:status
      })
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # for API compatibility

  def kata_new
    nil
  end

  def kata_old
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # for API compatibility

  def avatar_new(_avatar_name, _starting_files)
    nil
  end

  def avatar_old(_avatar_name)
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    avatar_name,
    new_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    @avatar_name = avatar_name
    deleted_files = nil # we're stateless
    all_files = [*new_files, *unchanged_files, *changed_files].to_h
    Dir.mktmpdir do |tmp_dir|
      save_to(all_files, tmp_dir)
      in_container(max_seconds) {
        inject_tar_script
        run_timeout(tar_pipe_from(tmp_dir), max_seconds)
        if @timed_out
          @colour = 'timed_out'
          @files = {}
        else
          @colour = red_amber_green
          tar_pipe_to(tmp_dir)
          @files = read_from(tmp_dir)
        end
      }
    end
    {
      files:@files,
      stdout:@stdout,
      stderr:@stderr,
      status:@status,
      colour:@colour
    }
  end

  private # = = = = = = = = = = = = = = = = = =

  attr_reader :kata_id, :avatar_name, :image_name

  attr_reader :disk, :shell

  def save_to(files, tmp_dir)
    files.each do |pathed_filename, content|
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

  def read_from(tmp_dir)
    files = {}
    tmp_dir += sandbox_dir
    Find.find(tmp_dir) do |pathed_filename|
      unless File.directory?(pathed_filename)
        content = File.read(pathed_filename)
        filename = pathed_filename[tmp_dir.size+1..-1]
        files[filename] = truncated(cleaned(content))
      end
    end
    files
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def inject_tar_script
    # TODO: The plan is to install this shell script directly
    # inside the test-framework images (using image_builder)
    sh = <<-SHELL
      rm -f ${TAR_LIST} | true
      find ${CYBER_DOJO_SANDBOX} -type f -exec sh -c '
        for filename do
          if file --mime-encoding ${filename} | grep -qv "${filename}:\sbinary"; then
            echo ${filename} >> ${TAR_LIST}
          fi
        done' sh {} +
    SHELL

    Dir.mktmpdir do |tmp_dir2|
      filename = "#{tmp_dir2}/create_tar_list.sh"
      File.write(filename, sh)
      create_cmd = "(docker exec -i #{container_name} bash -c 'cat > /tmp/create_tar_list.sh') < #{filename}"
      shell.assert(create_cmd)
      chmod = 'chmod +x /tmp/create_tar_list.sh'
      shell.assert("docker exec #{container_name} bash -c '#{chmod}'")
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_to(tmp_dir)
    # You cannot pass the tar-list filename as an argument
    # to create_tar_list.sh because of the bash -c
    tar_list = '/tmp/tar.list'
    docker_tar_pipe =
      "docker exec --env TAR_LIST=#{tar_list} #{container_name} bash -c " +
      "'/tmp/create_tar_list.sh && tar -cf - -T #{tar_list}'" +
      '|' +
      "tar -xf - -C #{tmp_dir}"
    shell.assert(docker_tar_pipe)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_from(tmp_dir)
    # In a stateless runner _all_ files are sent from the
    # browser, and cyber-dojo.sh cannot be deleted so there
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
    #    o) update_tar_command
    #    o) install_coreutils_command
    <<~SHELL.strip
      chmod 755 #{tmp_dir}                                 \
      &&                                                   \
      cd #{tmp_dir}                                        \
      &&                                                   \
      tar                                                  \
        -zcf                     `# create tar file`       \
        -                        `# write it to stdout`    \
        .                        `# tar current directory` \
        |                        `# pipe the tarfile`      \
          docker exec            `# into docker container` \
            --user=#{uid}:#{gid}                           \
            --interactive                                  \
            #{container_name}                              \
            sh -c                                          \
              '                  `# open quote`            \
              cd #{sandbox_dir}                            \
              &&                                           \
              tar                                          \
                --touch          `# [1]`                   \
                -zxf             `# extract tar file`      \
                -                `# read from stdin`       \
                -C               `# save to the`           \
                .                `# current directory`     \
              &&                                           \
              bash ./cyber-dojo.sh                         \
              '                  `# close quote`
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_timeout(cmd, max_seconds)
    # The [docker exec] running on the _host_ is
    # killed by Process.kill. This does _not_ kill
    # the cyber-dojo.sh running _inside_ the docker
    # container. The container is killed in the ensure
    # block of in_container()
    # See https://github.com/docker/docker/issues/9098
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    pid = Process.spawn(cmd, {
      pgroup:true,     # become process leader
         out:w_stdout, # redirection
         err:w_stderr  # redirection
    })
    begin
      Timeout::timeout(max_seconds) do
        _, ps = Process.waitpid2(pid)
        @status = ps.exitstatus
        @timed_out = (@status == 137)
      end
    rescue Timeout::Error
      Process.kill(-9, pid) # -ve means kill process-group
      Process.detach(pid)   # prevent zombie-child
      @status = 137         # don't wait for status from detach
      @timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      @stdout = truncated(cleaned(r_stdout.read))
      @stderr = truncated(cleaned(r_stderr.read))
      r_stdout.close
      r_stderr.close
    end
  end

  include StringCleaner
  include StringTruncater

  # - - - - - - - - - - - - - - - - - - - - - -

  def red_amber_green
    # @stdout and @stderr have been truncated and cleaned.
    begin
      # In a crippled container (eg fork-bomb)
      # the [docker exec] will mostly likely raise.
      cmd = 'cat /usr/local/bin/red_amber_green.rb'
      rag_lambda = shell.assert(docker_exec(cmd))
      rag = eval(rag_lambda)
      colour = rag.call(@stdout, @stderr, @status)
      unless [:red,:amber,:green].include?(colour)
        colour = :amber
      end
      colour.to_s
    rescue
     'amber'
    end
  end

  def docker_exec(cmd)
    # This is _not_ the main docker-exec inside run_cyber_dojo_sh
    "docker exec --user=root #{container_name} sh -c '#{cmd}'"
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # image/container
  # - - - - - - - - - - - - - - - - - - - - - -

  def in_container(max_seconds)
    create_container(max_seconds)
    begin
      yield
    ensure
      remove_container
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(max_seconds)
    chown = "chown #{avatar_name}:#{group} #{sandbox_dir}"
    docker_run = [
      'docker run',
        docker_run_options,
        image_name,
          "sh -c '#{chown} && sleep #{max_seconds}'"
    ].join(space)
    shell.assert(docker_run)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def remove_container
    # [docker rm] could be backgrounded with a trailing &
    # but it did not make a test-event discernably
    # faster when measuring to 100th of a second.
    shell.assert("docker rm --force #{container_name}")
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name
    [ name_prefix, kata_id, avatar_name ].join('_')
  end

  def name_prefix
    'test_run__runner_stateless'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_options
    # no volume-mount; stateless!
    options = <<~SHELL.strip
      --detach                  `# later exec`       \
      #{env_vars}                                    \
      --init                    `# pid-1 process`    \
      --name=#{container_name}  `# easy cleanup`     \
      #{limits}                                      \
      --user=root               `# chown permission` \
      --workdir=#{sandbox_dir}  `# creates the dir`
    SHELL
    if clang?
      # For the -fsanitize=address option.
      options += '--cap-add=SYS_PTRACE'
    end
    options
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def env_vars
    [
      env_var('AVATAR_NAME', avatar_name),
      env_var('IMAGE_NAME',  image_name),
      env_var('KATA_ID',     kata_id),
      env_var('RUNNER',      'stateless'),
      env_var('SANDBOX',     sandbox_dir)
    ].join(space)
  end

  def env_var(name, value)
    "--env CYBER_DOJO_#{name}=#{value}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def limits
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
      # [ulimit data] prevents clang's -fsanitize=address option.
      options << ulimit('data', 4*GB) # data segment size
    end
    options.join(space)
  end

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}"
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - -
  # avatar
  # - - - - - - - - - - - - - - - - - -

  def group
    'cyber-dojo'
  end

  def gid
    5000
  end

  def uid
    40000 + all_avatars_names.index(avatar_name)
  end

  def sandbox_dir
    "/sandboxes/#{avatar_name}"
  end

  include AllAvatarsNames

  # - - - - - - - - - - - - - - - - - -

  def space
    ' '
  end

end

# - - - - - - - - - - - - - - - - - - - - - - - -
# The implementation of run_timeout_cyber_dojo_sh is
#   o) create copies of all files off /tmp
#   o) one tar-pipe copying /tmp files into the container
#   o) run cyber-dojo.sh inside the container
#
# An alternative implementation is
#   o) don't create copies of files off /tmp
#   o) N tar-pipes for N files, each copying directly into the container
#   o) run cyber-dojo.sh inside the container
#
# If only one file has changed you might image this is quicker
# but testing shows its actually a bit slower.
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

# What ulimits are supported? See https://github.com/docker/go-units/blob/f2145db703495b2e525c59662db69a7344b00bb8/ulimit.go#L46-L62
