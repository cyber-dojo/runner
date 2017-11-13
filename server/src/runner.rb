require_relative 'all_avatars_names'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require_relative 'valid_image_name'
require 'timeout'

class Runner # stateless

  def initialize(parent, image_name, kata_id)
    @disk = parent.disk
    @shell = parent.shell
    @image_name = image_name
    @kata_id = kata_id
    assert_valid_image_name
    assert_valid_kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?
    image_names.include? image_name
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
      fail invalid_argument('image_name')
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def kata_new
    # no-op for API compatibility
  end

  def kata_old
    # no-op for API compatibility
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new(avatar_name, _starting_files)
    @avatar_name = avatar_name
    assert_valid_avatar_name
    # no-op for API compatibility
  end

  def avatar_old(avatar_name)
    @avatar_name = avatar_name
    assert_valid_avatar_name
    # no-op for API compatibility
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    avatar_name,
    deleted_files, unchanged_files, changed_files, new_files,
    max_seconds
  )
    deleted_files = nil # we're stateless
    all_files = [*unchanged_files, *changed_files, *new_files].to_h
    run(avatar_name, all_files, max_seconds)
  end

  def run(avatar_name, visible_files, max_seconds)
    @avatar_name = avatar_name
    assert_valid_avatar_name
    stdout,stderr,status,colour = Dir.mktmpdir do |tmp_dir|
      save_to(visible_files, tmp_dir)
      in_container {
        run_timeout(tar_pipe_from(tmp_dir), max_seconds)
      }
    end
    { stdout:truncated(stdout),
      stderr:truncated(stderr),
      status:status,
      colour:colour
    }
  end

  private # = = = = = = = = = = = = = = = = = =

  def docker_run_options
    # no volume-mount; stateless!
    [
      '--detach',                 # for later exec
      env_vars,
      '--init',                   # pid-1 process
      '--interactive',            # for tar-pipe
      limits,
      "--name=#{container_name}", # for easy cleanup
      '--user=root',              # chown permission
      "--workdir=#{sandbox_dir}"  # creates the dir
    ].join(space)
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
    [                          # max
      ulimit('data',   4*GB),  # data segment size
      ulimit('core',   0),     # core file size
      ulimit('fsize',  16*MB), # file size
      ulimit('locks',  128),   # number of file locks
      ulimit('nofile', 128),   # number of files
      ulimit('nproc',  128),   # number of processes
      ulimit('stack',  8*MB),  # stack size
      '--memory=384m',         # ram
      '--net=none',                      # no network
      '--pids-limit=128',                # no fork bombs
      '--security-opt=no-new-privileges' # no escalation
    ].join(space)
    # There is no cpu-ulimit. This is because a cpu-ulimit of 10
    # seconds could kill a container after only 5 seconds...
    # The cpu-ulimit assumes one core. The host system running the
    # docker container can have multiple cores or use hyperthreading.
    # So a piece of code running on 2 cores, both 100% utilized could
    # be killed after 5 seconds.
  end

  def ulimit(name, limit)
    "--ulimit #{name}=#{limit}:#{limit}"
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  # - - - - - - - - - - - - - - - - - - - - - -

  def save_to(files, tmp_dir)
    # In a stateless runner _all_ files are sent
    # from the browser, and cyber-dojo.sh cannot
    # be deleted so there must be at least one file.
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
    [
      "chmod 755 #{tmp_dir}",
      "&& cd #{tmp_dir}",
      '&& tar',
            '-zcf', # create tar file
            '-',    # write it to stdout
            '.',    # tar the current directory
            '|',    # pipe the tarfile...
                'docker exec',  # ...into docker container
                  "--user=#{uid}:#{gid}", # ownership
                  '--interactive',
                  container_name,
                  'sh -c',
                  "'",         # open quote
                  "cd #{sandbox_dir}",
                  '&& tar',
                        '--touch', # [1]
                        '-zxf',    # extract tar file
                        '-',       # which is read from stdin
                        '-C',      # save the extracted files to
                        '.',       # the current directory
                  '&& sh ./cyber-dojo.sh',
                  "'"          # close quote
    ].join(space)
    # [1] is for file-stamp date-time granularity
    # This relates to the modification-date (stat %y).
    # The tar --touch option is not available in a default Alpine
    # container. To add it:
    #
    #    $ apk add --update tar
    #
    # Also, in a default Alpine container the date-time
    # file-stamps have a granularity of one second. In other
    # words the microseconds value is always zero.
    # To add microsecond granularity:
    #
    #    $ apk add --update coreutils
    #
    # See the file builder/image_builder.rb on
    # https://github.com/cyber-dojo-languages/image_builder/blob/master/
    # In particular the methods
    #    o) update_tar_command
    #    o) install_coreutils_command
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  include StringCleaner
  include StringTruncater

  def run_timeout(cmd, max_seconds)
    # This kills the container from the "outside". Originally
    # I also time-limited the cpu-time from the "inside" using
    # a cpu ulimit. See comment on the ulimit method.
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    pid = Process.spawn(cmd, {
      pgroup:true,
         out:w_stdout,
         err:w_stderr
    })
    begin
      Timeout::timeout(max_seconds) do
        Process.waitpid(pid)
        status = $?.exitstatus
        w_stdout.close
        w_stderr.close
        stdout = cleaned(r_stdout.read)
        stderr = cleaned(r_stderr.read)
        colour = red_amber_green(stdout, stderr, status)
        [stdout, stderr, status, colour]
      end
    rescue Timeout::Error
      # Kill the [docker exec] processes running on the host.
      # This does __not__ kill the cyber-dojo.sh process running
      # __inside__ the docker container.
      # The container is killed in the ensure block of the
      # in_container method.
      # See https://github.com/docker/docker/issues/9098
      Process.kill(-9, pid)
      Process.detach(pid)
      stdout = ''
      stderr = ''
      status = 137
      colour = 'timed_out'
      [stdout, stderr, status, colour]
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def red_amber_green(stdout_arg, stderr_arg, status_arg)
    # If cyber-dojo.sh has crippled the container (eg fork-bomb)
    # then the [docker exec] will mostly likely raise.
    # Not worth creating a new container for this.
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    begin
      # The rag lambda tends to look like this:
      #   lambda { |stdout, stderr, status| ... }
      # so avoid using stdout,stderr,status as identifiers
      # or you'll get shadowing outer local variables warnings.
      out,_err = assert_exec("docker exec #{container_name} sh -c '#{cmd}'")
      rag = eval(out)
      colour = rag.call(stdout_arg, stderr_arg, status_arg).to_s
      unless ['red','amber','green'].include? colour
        colour = 'amber'
      end
      colour
    rescue
      'amber'
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # images
  # - - - - - - - - - - - - - - - - - - - - - -

  def image_names
    cmd = 'docker images --format "{{.Repository}}"'
    stdout,_ = assert_exec(cmd)
    names = stdout.split("\n")
    names.uniq - [ '<none>' ]
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # image_name
  # - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :image_name

  def assert_valid_image_name
    unless valid_image_name?(image_name)
      fail invalid_argument('image_name')
    end
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - - - - - - - -
  # container
  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name
    'test_run__runner_stateless_' + kata_id + '_' + avatar_name
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
    assert_exec(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def remove_container
    # [docker rm] could be backgrounded with a trailing &
    # but it did not make a test-event discernably
    # faster when measuring to 100th of a second.
    assert_exec("docker rm --force #{container_name}")
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # container properties
  # - - - - - - - - - - - - - - - - - - - - - -

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
    "/tmp/sandboxes/#{avatar_name}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -
  # kata_id
  # - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :kata_id

  def assert_valid_kata_id
    unless valid_kata_id?
      fail invalid_argument('kata_id')
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
  # avatar_name
  # - - - - - - - - - - - - - - - - - -

  attr_reader :avatar_name

  def assert_valid_avatar_name
    unless valid_avatar_name?
      fail invalid_argument('avatar_name')
    end
  end

  def valid_avatar_name?
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

  # - - - - - - - - - - - - - - - - - -
  # helpers
  # - - - - - - - - - - - - - - - - - -

  def invalid_argument(name)
    ArgumentError.new("#{name}:invalid")
  end

  def assert_exec(cmd)
    shell.assert_exec(cmd)
  end

  def space
    ' '
  end

  attr_reader :disk, :shell # externals

end

# - - - - - - - - - - - - - - - - - - - - - - - -
# The implementation of run_timeout_cyber_dojo_sh is
#   o) Create copies of all files off /tmp
#   o) Tar pipe the /tmp files into the container
#   o) Run cyber-dojo.sh inside the container
#
# An alternative implementation is
#   o) Tar pipe each file's content directly into the container
#   o) Run cyber-dojo.sh inside the container
#
# If only one file has changed you might image this is quicker
# but testing shows its actually a bit slower.
#
# For interest's sake here's how you tar pipe from a string and
# avoid the intermediate /tmp files. I don't know how this
# would affect the date-time file-stamp granularity (stat %y).
#
# require 'open3'
# files.each do |name,content|
#   filename = avatar_dir + '/' + name
#   dir = File.dirname(filename)
#   shell_cmd = "mkdir -p #{dir};"
#   shell_cmd += "cat > #{filename} && chown #{uid}:#{gid} #{filename}"
#   cmd = "docker exec --interactive --user=root #{cid} sh -c '#{shell_cmd}'"
#   stdout,stderr,ps = Open3.capture3(cmd, :stdin_data => content)
#   assert ps.success?
# end
# - - - - - - - - - - - - - - - - - - - - - - - -
