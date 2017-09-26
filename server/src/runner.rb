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

  attr_reader :image_name, :kata_id

  # - - - - - - - - - - - - - - - - - -

  def image_pulled?
    image_names.include? image_name
  end

  # - - - - - - - - - - - - - - - - - -

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

  # - - - - - - - - - - - - - - - - - -

  def run(avatar_name, visible_files, max_seconds)
    assert_valid_avatar_name(avatar_name)
    in_container(avatar_name) {
      stdout,stderr,status = run_cyber_dojo_sh(avatar_name, visible_files, max_seconds)
      colour = red_amber_green(avatar_name, stdout, stderr, status)
      { stdout:stdout,
        stderr:stderr,
        status:status,
        colour:colour
      }
    }
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

  attr_reader :disk, :shell

  def in_container(avatar_name, &block)
    create_container(avatar_name)
    begin
      block.call
    ensure
      # [docker rm] could be backgrounded with a trailing &
      # but it does not make a test-event discernably
      # faster when measuring to 100th of a second
      container = container_name(avatar_name)
      assert_exec("docker rm --force #{container}")
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def create_container(avatar_name)
    sandbox = sandbox_dir(avatar_name)
    home = home_dir(avatar_name)
    name = container_name(avatar_name)
    max = 128
    cmd = [
      'docker run',
        '--detach',
        "--env CYBER_DOJO_AVATAR_NAME=#{avatar_name}",
        "--env CYBER_DOJO_KATA_ID=#{kata_id}",
        "--env CYBER_DOJO_SANDBOX=#{sandbox}",
        "--env HOME=#{home}",
        '--interactive',                     # for later execs
        "--name=#{name}",
        '--net=none',                        # no network
        "--pids-limit=#{max}",               # no fork bombs
        '--security-opt=no-new-privileges',  # no escalation
        '--ulimit core=0:0',                 # max core file size = 0 blocks
        "--ulimit nofile=#{max}:#{max}",     # max number of files
        "--ulimit nproc=#{max}:#{max}",      # max number processes
        "--workdir=#{sandbox}",
        '--user=root',                       # chown needs permission
        image_name,
        'sh',
        '-c',
        "'chown #{avatar_name}:#{group} #{sandbox};sh'"
    ].join(space)
    assert_exec(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(avatar_name, visible_files, max_seconds)
    # See comment at end of file about slower alternative.
    Dir.mktmpdir('runner') do |tmp_dir|
      # save the files onto the host...
      visible_files.each do |pathed_filename, content|
        sub_dir = File.dirname(pathed_filename)
        if sub_dir != '.'
          src_dir = tmp_dir + '/' + sub_dir
          shell.exec("mkdir -p #{src_dir}")
        end
        host_filename = tmp_dir + '/' + pathed_filename
        disk.write(host_filename, content)
      end
      # ...then tar-pipe them into the container
      # and run cyber-dojo.sh
      uid = user_id(avatar_name)
      container = container_name(avatar_name)
      sandbox = sandbox_dir(avatar_name)
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
                    container,
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

  include StringCleaner
  include StringTruncater

  def run_timeout(cmd, max_seconds)
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
      # The container is killed in the ensure
      # block of in_container()
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

  def red_amber_green(avatar_name, stdout_arg, stderr_arg, status_arg)
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    container = container_name(avatar_name)
    out,_err = assert_docker_exec(container, cmd)
    rag = eval(out)
    rag.call(stdout_arg, stderr_arg, status_arg).to_s
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # images
  # - - - - - - - - - - - - - - - - - - - - - -

  def image_names
    cmd = 'docker images --format "{{.Repository}}"'
    stdout,_ = assert_exec(cmd)
    names = stdout.split("\n")
    names.uniq - ['<none>']
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def container_name(avatar_name)
    # give containers a name with a specific prefix so they
    # can be cleaned up if any fail to be removed/reaped.
    'test_run__runner_stateless_' + kata_id + '_' + avatar_name
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  include ValidImageName

  def assert_valid_image_name
    unless valid_image_name?(image_name)
      fail invalid_argument('image_name')
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -
  # kata_id
  # - - - - - - - - - - - - - - - - - - - - - - - -

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

  include AllAvatarsNames

  def assert_valid_avatar_name(avatar_name)
    unless valid_avatar_name?(avatar_name)
      fail invalid_argument('avatar_name')
    end
  end

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  # - - - - - - - - - - - - - - - - - -

  def invalid_argument(name)
    ArgumentError.new("#{name}:invalid")
  end

  # - - - - - - - - - - - - - - - - - -

  def assert_docker_exec(cid, cmd)
    assert_exec("docker exec #{cid} sh -c '#{cmd}'")
  end

  def assert_exec(cmd)
    shell.assert_exec(cmd)
  end

  # - - - - - - - - - - - - - - - - - -

  def space
    ' '
  end

end

# - - - - - - - - - - - - - - - - - - - - - - - -
# The implementation of run_cyber_dojo_sh is
#   o) Create copies of all files off /tmp
#   o) Tar pipe the /tmp files into the container
#   o) Run cyber-dojo.sh inside the container
#
# An alternative implementation is
#   o) Tar pipe each file's content directly into the container
#   o) Run cyber-dojo.sh inside the container
#
# You might image this is quicker
# but testing shows its slower.
#
# For interest's sake here's how you tar pipe from a string and
# avoid the intermediate /tmp files:
#
# require 'open3'
# files.each do |name,content|
#   filename = avatar_dir + '/' + name
#   dir = File.dirname(filename)
#   shell_cmd = "mkdir -p #{dir};"
#   shell_cmd += "cat >#{filename} && chown #{uid}:#{gid} #{filename}"
#   cmd = "docker exec --interactive --user=root #{cid} sh -c '#{shell_cmd}'"
#   stdout,stderr,ps = Open3.capture3(cmd, :stdin_data => content)
#   assert ps.success?
# end
# - - - - - - - - - - - - - - - - - - - - - - - -
