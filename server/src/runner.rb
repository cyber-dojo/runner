require_relative 'all_avatars_names'
require_relative 'nearest_ancestors'
require_relative 'logger_null'
#require_relative 'string_cleaner'
#require_relative 'string_truncater'
#require 'timeout'

class Runner

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent # For nearest_ancestors()

  def image_pulled?(image_name)
    assert_valid_image_name image_name
    image_names.include? image_name
  end

  # - - - - - - - - - - - - - - - - - -

  def image_pull(image_name)
    assert_valid_image_name image_name
    assert_exec "docker pull #{image_name}"
    true
  end

  # - - - - - - - - - - - - - - - - - -

  def run(image_name, avatar_name, visible_files, max_seconds)
    assert_valid_image_name image_name
    assert_valid_avatar_name avatar_name
    in_container(image_name) do |cid|
      #write_files(cid, avatar_name, visible_files)
      #stdout,stderr,status = run_cyber_dojo_sh(cid, max_seconds)
      stdout,stderr,status = '','',0
      { stdout:stdout, stderr:stderr, status:status }
    end
  end

  private

  def in_container(image_name, &block)
    cid = create_container(image_name)
    begin
      block.call(cid)
    ensure
      remove_container(cid)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(image_name)
    #dir = avatar_dir(avatar_name)
    #home = home_dir(avatar_name)
    args = [
      '--detach',                          # get the cid
      '--interactive',                     # for later execs
      '--net=none',                        # for security
      '--pids-limit=64',                   # no fork bombs
      '--security-opt=no-new-privileges',  # no escalation
      '--ulimit nproc=64:64',              # max number processes = 64
      '--ulimit core=0:0',                 # max core file size = 0 blocks
      '--ulimit nofile=128:128',           # max number of files = 128
      #"--env CYBER_DOJO_KATA_ID=#{kata_id}",
      #"--env CYBER_DOJO_AVATAR_NAME=#{avatar_name}",
      #"--env CYBER_DOJO_SANDBOX=#{dir}",
      #"--env HOME=#{home}",
      '--user=root',
      #"--volume #{volume_name}:#{volume_root}:rw"
    ].join(space = ' ')
    stdout,_ = assert_exec("docker run #{args} #{image_name} sh")
    cid = stdout.strip
    #assert_docker_exec(cid, add_group_cmd(cid))
    #assert_docker_exec(cid, add_user_cmd(cid, avatar_name))
    cid
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def remove_container(cid)
    assert_exec("docker rm --force #{cid}")
    # The docker daemon responds to [docker rm]
    # asynchronously...
    # An 'immediately' following old_avatar()'s
    #    [docker volume rm]
    # might fail since the container is not quite dead yet.
    # This is unlikely to happen in real use but quite
    # likely in tests. I considered making old_avatar()
    # check the container was dead.
    #   pro) remove_container will never do a sleep
    #        (delaying a run)
    #   con) would mean storing the cid in the volume
    #        somewhere
    # I'm waiting max 2 seconds for the container to die.
    # o) no delay if container_dead? is true 1st time.
    # o) 0.04s delay if container_dead? is true 2nd time.
    removed = false
    tries = 0
    while !removed && tries < 50
      removed = container_dead?(cid)
      sleep(1.0 / 25.0) unless removed
      tries += 1
    end
    log << "Failed:remove_container(#{cid})" unless removed
  end

  def container_dead?(cid)
    cmd = "docker inspect --format='{{ .State.Running }}' #{cid}"
    _,stderr,status = quiet_exec(cmd)
    expected_stderr = "Error: No such image, container or task: #{cid}"
    (status == 1) && (stderr.strip == expected_stderr)
  end

  def quiet_exec(cmd)
    shell.exec(cmd, LoggerNull.new(self))
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # - - - - - - - - - - - - - - - - - - - - - -

=begin
  def write_files(cid, avatar_name, visible_files)
    return if visible_files == {}
    Dir.mktmpdir('runner') do |tmp_dir|
      files.each do |filename, content|
        host_filename = tmp_dir + '/' + filename
        disk.write(host_filename, content)
      end
      dir = avatar_dir(avatar_name)
      assert_exec("docker cp #{tmp_dir}/. #{cid}:#{dir}")
      files.keys.each do |filename|
        chown_file = "chown #{avatar_name}:#{group} #{dir}/#{filename}"
        assert_docker_exec(cid, chown_file)
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(cid, avatar_name, max_seconds)
    # I thought doing [chmod 755] in new_avatar() would
    # be "sticky" and remain 755 but it appears not...
    uid = user_id(avatar_name)
    dir = avatar_dir(avatar_name)
    docker_cmd = [
      'docker exec',
      "--user=#{uid}:#{gid}",
      '--interactive',
      cid,
      "sh -c 'cd #{dir} && chmod 755 . && sh ./cyber-dojo.sh'"
    ].join(space = ' ')

    run_timeout(docker_cmd, max_seconds)
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
      Process.kill(-9, pid)
      Process.detach(pid)
      ['', '', 'timed_out']
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      r_stdout.close
      r_stderr.close
    end
  end
=end

  # - - - - - - - - - - - - - - - - - -
  # - - - - - - - - - - - - - - - - - -

  def image_names
    cmd = 'docker images --format "{{.Repository}}"'
    stdout,_ = assert_exec(cmd)
    names = stdout.split("\n")
    names.uniq - ['<none>']
  end

  # - - - - - - - - - - - - - - - - - -

  def assert_valid_image_name(image_name)
    unless valid_image_name? image_name
      fail_image_name('invalid')
    end
  end

  def valid_image_name?(image_name)
    # http://stackoverflow.com/questions/37861791/
    #      how-are-docker-image-names-parsed
    # https://github.com/docker/docker/blob/master/image/spec/v1.1.md
    # Simplified, no hostname, no :tag
    alpha_numeric = '[a-z0-9]+'
    separator = '[_.-]+'
    component = "#{alpha_numeric}(#{separator}#{alpha_numeric})*"
    name = "#{component}(/#{component})*"
    image_name =~ /^#{name}$/o
  end

  def fail_image_name(message)
    fail bad_argument("image_name:#{message}")
  end

  # - - - - - - - - - - - - - - - - - -

  def assert_valid_avatar_name(avatar_name)
    unless valid_avatar_name?(avatar_name)
      fail_avatar_name('invalid')
    end
  end

  include AllAvatarsNames
  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  def fail_avatar_name(message)
    fail bad_argument("avatar_name:#{message}")
  end

  # - - - - - - - - - - - - - - - - - -

  def bad_argument(message)
    ArgumentError.new(message)
  end

  def assert_exec(cmd)
    shell.assert_exec(cmd)
  end

  include NearestAncestors
  def shell; nearest_ancestors(:shell); end
  def  disk; nearest_ancestors(:disk); end
  def   log; nearest_ancestors(:log); end

end
