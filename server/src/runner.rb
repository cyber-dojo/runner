require_relative 'all_avatars_names'
require_relative 'logger_null'
require_relative 'nearest_ancestors'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require_relative 'valid_image_name'
require 'securerandom'
require 'timeout'

class Runner

  def initialize(parent, image_name, kata_id)
    @parent = parent
    @image_name = image_name
    @kata_id = kata_id
    assert_valid_image_name
    assert_valid_kata_id
  end

  attr_reader :parent # For nearest_ancestors()
  attr_reader :image_name
  attr_reader :kata_id

  # - - - - - - - - - - - - - - - - - -

  def image_pulled?
    image_names.include? image_name
  end

  # - - - - - - - - - - - - - - - - - -

  def image_pull
    # [1] The contents of stderr seem to vary depending
    # on what your running on, eg DockerToolbox or not
    # and where, eg Travis or not. I'm using 'not found'
    # as that always seems to be present.
    _stdout,stderr,status = quiet_exec("docker pull #{image_name}")
    if status == shell.success
      return true
    elsif stderr.include?('not found') # [1]
      return false
    else
      fail stderr
    end
  end

  # - - - - - - - - - - - - - - - - - -

  def run(avatar_name, visible_files, max_seconds)
    assert_valid_avatar_name avatar_name
    in_container(avatar_name) do |cid|
      stdout,stderr,status = run_cyber_dojo_sh(cid, avatar_name, visible_files, max_seconds)
      colour = red_amber_green(cid, stdout, stderr, status)
      { stdout:stdout, stderr:stderr, status:status, colour:colour }
    end
  end

  # - - - - - - - - - - - - - - - - - -

  def group
    'cyber-dojo'
  end

  def gid
    5000
  end

  def user_id(avatar_name)
    40000 + all_avatars_names.index(avatar_name)
  end

  def home_dir(avatar_name)
    "/home/#{avatar_name}"
  end

  def sandbox_dir(avatar_name)
    "/tmp/sandboxes/#{avatar_name}"
  end

  def timed_out
    'timed_out'
  end

  private

  def in_container(avatar_name, &block)
    cid = create_container(avatar_name)
    begin
      block.call(cid)
    ensure
      remove_container(cid)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(avatar_name)
    # chowning requires root permissions so
    # the user cannot be the avatar
    sandbox = sandbox_dir(avatar_name)
    home = home_dir(avatar_name)
    name = "test_run__runner_stateless_#{kata_id}_#{avatar_name}_#{uuid}"
    max = 128
    cmd = [
      'docker run',
        '--detach',                          # get the cid
        '--interactive',                     # for later execs
        "--name=#{name}",                    # for easy clean up
        '--net=none',                        # no network
        '--security-opt=no-new-privileges',  # no escalation
        "--pids-limit=#{max}",               # no fork bombs
        "--ulimit nproc=#{max}:#{max}",      # max number processes
        "--ulimit nofile=#{max}:#{max}",     # max number of files
        '--ulimit core=0:0',                 # max core file size = 0 blocks
        "--env CYBER_DOJO_KATA_ID=#{kata_id}",
        "--env CYBER_DOJO_AVATAR_NAME=#{avatar_name}",
        "--env CYBER_DOJO_SANDBOX=#{sandbox}",
        "--env HOME=#{home}",
        '--user=root',
        "--workdir=#{sandbox}",
        image_name,
        'sh',
        '-c',
        "'chown #{avatar_name}:#{group} #{sandbox};sh'"
    ].join(space)
    stdout,_ = assert_exec(cmd)
    stdout.strip # cid
  end

  def uuid
    SecureRandom.hex[0..10].upcase
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def remove_container(cid)
    assert_exec("docker rm --force #{cid}")
    # The docker daemon responds to [docker rm] asynchronously...
    # I'm waiting max 2 seconds for the container to die.
    # o) no delay if container_dead? is true 1st time.
    # o) 0.04s delay if container_dead? is true 2nd time, etc
    removed = false
    tries = 0
    while !removed && tries < 50
      removed = container_dead?(cid)
      unless removed
        assert_exec("sleep #{1.0 / 25.0}")
      end
      tries += 1
    end
    unless removed
      log << "Failed to confirm:remove_container(#{cid})"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def container_dead?(cid)
    cmd = "docker inspect --format='{{ .State.Running }}' #{cid}"
    _,stderr,status = quiet_exec(cmd)
    expected_stderr = "Error: No such image, container or task: #{cid}"
    (status == 1) && (stderr.strip == expected_stderr)
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(cid, avatar_name, visible_files, max_seconds)
    Dir.mktmpdir('runner') do |tmp_dir|
      visible_files.each do |pathed_filename, content|
        sub_dir = File.dirname(pathed_filename)
        if sub_dir != '.'
          src_dir = tmp_dir + '/' + sub_dir
          shell.exec("mkdir -p #{src_dir}")
        end
        host_filename = tmp_dir + '/' + pathed_filename
        disk.write(host_filename, content)
      end
      sandbox = sandbox_dir(avatar_name)
      uid = user_id(avatar_name)
      tar_pipe = [
        "chmod 755 #{tmp_dir}",
        "&& cd #{tmp_dir}",
        '&& tar',
              "--owner=#{uid}",
              "--group=#{gid}",
              '-zcf',             # create a compressed tar file
              '-',                # write it to stdout
              '.',                # tar the current directory
              '|',
                  'docker exec',  # pipe the tarfile into docker container
                    "--user=#{uid}:#{gid}",
                    '--interactive',
                    cid,
                    'sh -c',
                    "'",          # open quote
                    "cd #{sandbox}",
                    '&& tar',
                          '-zxf', # extract from a compressed tar file
                          '-',    # which is read from stdin
                          '-C',   # save the extracted files to
                          '.',    # the current directory
                    '&& sh ./cyber-dojo.sh',
                    "'",          # close quote
      ].join(space)
      run_timeout(tar_pipe, max_seconds)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_timeout(docker_cmd, max_seconds)
    r_stdout, w_stdout = IO.pipe
    r_stderr, w_stderr = IO.pipe
    pid = Process.spawn(docker_cmd, {
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
        stdout = truncated(cleaned(r_stdout.read))
        stderr = truncated(cleaned(r_stderr.read))
        [stdout, stderr, status]
      end
    rescue Timeout::Error
      # Kill the [docker exec] processes running
      # on the host. This does __not__ kill the
      # cyber-dojo.sh process running __inside__
      # the docker container. See
      # https://github.com/docker/docker/issues/9098
      # The container is killed by remove_container().
      Process.kill(-9, pid)
      Process.detach(pid)
      ['', '', timed_out]
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def red_amber_green(cid, stdout_arg, stderr_arg, status_arg)
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    out,_err = assert_docker_exec(cid, cmd)
    rag = eval(out)
    rag.call(stdout_arg, stderr_arg, status_arg).to_s
  end

  include StringCleaner
  include StringTruncater

  def image_names
    cmd = 'docker images --format "{{.Repository}}"'
    stdout,_ = assert_exec(cmd)
    names = stdout.split("\n")
    names.uniq - ['<none>']
  end

  # - - - - - - - - - - - - - - - - - -

  def assert_valid_image_name
    unless valid_image_name?(image_name)
      fail_image_name('invalid')
    end
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_valid_kata_id
    unless valid_kata_id?
      fail_kata_id('invalid')
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

  def assert_valid_avatar_name(avatar_name)
    unless valid_avatar_name?(avatar_name)
      fail_avatar_name('invalid')
    end
  end

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

  # - - - - - - - - - - - - - - - - - -

  def fail_kata_id(message)
    fail bad_argument("kata_id:#{message}")
  end

  def fail_image_name(message)
    fail bad_argument("image_name:#{message}")
  end

  def fail_avatar_name(message)
    fail bad_argument("avatar_name:#{message}")
  end

  def bad_argument(message)
    ArgumentError.new(message)
  end

  # - - - - - - - - - - - - - - - - - -

  def assert_docker_exec(cid, cmd)
    assert_exec("docker exec #{cid} sh -c '#{cmd}'")
  end

  def assert_exec(cmd)
    shell.assert_exec(cmd)
  end

  def quiet_exec(cmd)
    shell.exec(cmd, LoggerNull.new(self))
  end

  # - - - - - - - - - - - - - - - - - -

  def shell
    nearest_ancestors(:shell)
  end

  def disk
    nearest_ancestors(:disk)
  end

  def log
    nearest_ancestors(:log)
  end

  include NearestAncestors

  def space
    ' '
  end

end
