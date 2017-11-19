require_relative 'all_avatars_names'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require_relative 'valid_image_name'
require 'timeout'

class Runner # stateless

  def initialize(external, image_name, kata_id)
    @external = external
    @image_name = image_name
    @kata_id = kata_id
    assert_valid_image_name
    assert_valid_kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?
    cmd = 'docker images --format "{{.Repository}}"'
    shell.assert(cmd).split("\n").include? image_name
  end

  def image_pull
    # [1] The contents of stderr vary depending on Docker version
    docker_pull = "docker pull #{image_name}"
    _stdout,stderr,status = shell.exec(docker_pull)
    if status == shell.success
      return true
    elsif stderr.include?('not found') || stderr.include?('not exist')
      return false # [1]
    else
      argument_error('image_name', 'invalid')
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def kata_exists?
    container_exists?
  end

  def kata_new
    # no-op for API compatibility
    nil
  end

  def kata_old
    # no-op for API compatibility
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def avatar_exists?(avatar_name)
    @avatar_name = avatar_name
    assert_valid_avatar_name
    container_exists?
  end

  def avatar_new(avatar_name, _starting_files)
    # for API compatibility
    @avatar_name = avatar_name
    assert_valid_avatar_name
    nil
  end

  def avatar_old(avatar_name)
    # for API compatibility
    @avatar_name = avatar_name
    assert_valid_avatar_name
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    avatar_name,
    new_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    deleted_files = nil # we're stateless
    all_files = [*new_files, *unchanged_files, *changed_files].to_h
    run(avatar_name, all_files, max_seconds)
  end

  def run(avatar_name, visible_files, max_seconds)
    @avatar_name = avatar_name
    assert_valid_avatar_name
    Dir.mktmpdir do |tmp_dir|
      save_to(visible_files, tmp_dir)
      in_container {
        run_timeout(tar_pipe_from(tmp_dir), max_seconds)
        @colour = @timed_out ? 'timed_out' : red_amber_green
      }
    end
    { stdout:@stdout, stderr:@stderr, status:@status, colour:@colour }
  end

  private # = = = = = = = = = = = = = = = = = =

  def save_to(files, tmp_dir)
    files.each do |pathed_filename, content|
      sub_dir = File.dirname(pathed_filename)
      unless sub_dir == '.'
        src_dir = tmp_dir + '/' + sub_dir
        shell.exec("mkdir -p #{src_dir}")
      end
      src_filename = tmp_dir + '/' + pathed_filename
      disk.write(src_filename, content)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_from(tmp_dir)
    # In a stateless runner _all_ files are sent from the
    # browser, and cyber-dojo.sh cannot be deleted so there
    # must be at least one file in tmp_dir.
    #
    # [1] is for file-stamp date-time granularity
    # This relates to the modification-date (stat %y).
    # The tar --touch option is not available in a default Alpine
    # container. To add it:
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
      chmod 755 #{tmp_dir} &&                                          \
      cd #{tmp_dir} &&                                                 \
      tar                                                              \
        -zcf                           `# create tar file`             \
        -                              `# write it to stdout`          \
        .                              `# tar the current directory`   \
        |                              `# pipe the tarfile...`         \
          docker exec                  `# ...into docker container`    \
            --user=#{uid}:#{gid}                                       \
            --interactive                                              \
            #{container_name}                                          \
            sh -c                                                      \
              '                        `# open quote`                  \
              cd #{sandbox_dir} &&                                     \
              tar                                                      \
                --touch                `# [1]`                         \
                -zxf                   `# extract tar file`            \
                -                      `# which is read from stdin`    \
                -C                     `# save the extracted files to` \
                .                      `# the current directory`       \
                && sh ./cyber-dojo.sh                                  \
              '                        `# close quote`
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
        @timed_out = false
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
    # In a crippled container (eg fork-bomb)
    # the [docker exec] will mostly likely raise.
    # Not worth creating a new container for this.
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    begin
      rag = eval(shell.assert(docker_exec(cmd)))
      colour = rag.call(@stdout, @stderr, @status).to_s
      unless ['red','amber','green'].include? colour
        colour = 'amber'
      end
      colour
    rescue
      'amber'
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # image/container
  # - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :image_name

  def assert_valid_image_name
    unless valid_image_name?(image_name)
      argument_error('image_name', 'invalid')
    end
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - - - - - - - -

  def container_exists?
    stdout = shell.assert("docker ps --format '{{.Names}}'")
    stdout.lines.any? { |line| line.strip == container_name }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def in_container
    create_container
    begin
      yield
    ensure
      remove_container
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container
    cmd = [
      'docker run',
        docker_run_options,
        image_name,
          "sh -c 'chown #{avatar_name}:#{group} #{sandbox_dir};sh'"
    ].join(space)
    shell.assert(cmd)
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
    <<~SHELL.strip
      --detach                  `# later exec`       \
      #{env_vars}                                    \
      --init                    `# pid-1 process`    \
      --interactive             `# tar pipe`         \
      --name=#{container_name}  `# easy cleanup`     \
      --user=root               `# chown permission` \
      --workdir=#{sandbox_dir}  `# creates the dir`
    SHELL
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
    <<~SHELL.strip
      #{ulimit('data'  ,   4*GB)}      `# data segment size`    \
      #{ulimit('core'  ,   0   )}      `# core file size`       \
      #{ulimit('fsize' ,  16*MB)}      `# file size`            \
      #{ulimit('locks' , 128   )}      `# number of file locks` \
      #{ulimit('nofile', 128   )}      `# number of files`      \
      #{ulimit('nproc' , 128   )}      `# number of processes`  \
      #{ulimit('stack' ,   8*MB)}      `# stack size`           \
      --memory=512m                    `# ram`                  \
      --net=none                       `# no network`           \
      --pids-limit=128                 `# no fork bombs`        \
      --security-opt=no-new-privileges `# no escalation`
    SHELL
  end

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}:#{limit}"
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  # - - - - - - - - - - - - - - - - - - - - - - - -
  # kata
  # - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :kata_id

  def assert_valid_kata_id
    unless valid_kata_id?
      argument_error('kata_id', 'invalid')
    end
  end

  def valid_kata_id?
    kata_id.class.name == 'String' &&
      kata_id.length == 10 &&
        kata_id.chars.all? { |char| hex?(char) }
  end

  def hex?(char)
    '0123456789ABCDEF'.include?(char)
  end

  # - - - - - - - - - - - - - - - - - -
  # avatar
  # - - - - - - - - - - - - - - - - - -

  attr_reader :avatar_name

  def assert_valid_avatar_name
    unless valid_avatar_name?
      argument_error('avatar_name', 'invalid')
    end
  end

  def valid_avatar_name?
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

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

  # - - - - - - - - - - - - - - - - - -
  # assertions
  # - - - - - - - - - - - - - - - - - -

  def docker_exec(cmd)
    "docker exec #{container_name} sh -c '#{cmd}'"
  end

  def argument_error(name, message)
    raise ArgumentError.new("#{name}:#{message}")
  end

  def disk
    @external.disk
  end

  def shell
    @external.shell
  end

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
#   filename = avatar_dir + '/' + name
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
