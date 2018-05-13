require_relative 'all_avatars_names'
require_relative 'file_delta'
require_relative 'string_cleaner'
require_relative 'string_truncater'
require 'timeout'
require 'find'

class Runner # stateless

  def initialize(external, cache)
    @external = external
    @cache = cache
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def sha
    IO.read('/app/sha.txt').strip
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # for API compatibility

  def kata_new(_image_name, _kata_id)
    nil
  end

  def kata_old(_image_name, _kata_id)
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # for API compatibility

  def avatar_new(_image_name, _kata_id, _avatar_name, _starting_files)
    nil
  end

  def avatar_old(_image_name, _kata_id, _avatar_name)
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    image_name, kata_id, avatar_name,
    new_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    @image_name = image_name
    @kata_id = kata_id
    @avatar_name = avatar_name
    deleted_files = nil # we're stateless
    all_files = [*new_files, *unchanged_files, *changed_files].to_h
    Dir.mktmpdir do |tmp_dir|
      save_to(all_files, tmp_dir)
      in_container(max_seconds) {
        run_timeout(tar_pipe_in(tmp_dir), max_seconds)
        set_colour
        set_file_delta(all_files)
      }
    end
    {
      stdout:@stdout,
      stderr:@stderr,
      status:@status,
      colour:@colour,
      new_files:@new_files,
      deleted_files:@deleted_files,
      changed_files:@changed_files
    }
  end

  private # = = = = = = = = = = = = = = = = = =

  attr_reader :image_name, :kata_id, :avatar_name

  # - - - - - - - - - - - - - - - - - - - - - -
  # read/write to /tmp on host
  # - - - - - - - - - - - - - - - - - - - - - -

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
    # eg tmp_dir = /tmp/.../sandboxes/bee
    files = {}
    Find.find(tmp_dir) do |pathed_filename|
      # eg pathed_filename =
      # '/tmp/.../sandboxes/bee/features/shouty.feature
      unless File.directory?(pathed_filename)
        content = File.read(pathed_filename)
        filename = pathed_filename[tmp_dir.size+1..-1]
        # eg filename = features/shouty.feature
        files[filename] = sanitized(content)
      end
    end
    files
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
      @status = 137         # don't wait for detach status
      @timed_out = true
    ensure
      w_stdout.close unless w_stdout.closed?
      w_stderr.close unless w_stderr.closed?
      @stdout = sanitized(r_stdout.read)
      @stderr = sanitized(r_stderr.read)
      r_stdout.close
      r_stderr.close
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # tar-piping into the container
  # - - - - - - - - - - - - - - - - - - - - - -

  def tar_pipe_in(tmp_dir)
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
    #    o) RUN_install_tar
    #    o) RUN_install_coreutils
    #    o) RUN_install_bash
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
  # tar-piping text files out of the container
  # - - - - - - - - - - - - - - - - - - - - - -

  include FileDelta

  def set_file_delta(was_files)
    now_files = tar_pipe_out
    if now_files == {} || @timed_out
      @new_files = {}
      @deleted_files = {}
      @changed_files = {}
    else
      file_delta(was_files, now_files)
    end
  end

  def tar_pipe_out
    # The create_text_file_tar_list.sh file is injected
    # into the test-framework image by image_builder.
    # Passes the tar-list filename as an environment
    # variable because using bash -c means you
    # cannot pass it as an argument.
    Dir.mktmpdir do |tmp_dir|
      tar_list = '/tmp/tar.list'
      docker_tar_pipe = <<~SHELL.strip
        docker exec --user=root                           \
          --env TAR_LIST=#{tar_list}                      \
          #{container_name}                               \
          bash -c                                         \
            '                                             \
            /usr/local/bin/create_text_file_tar_list.sh   \
            &&                                            \
            tar -zcf - -T #{tar_list}                     \
            '                                             \
              | tar -zxf - -C #{tmp_dir}
      SHELL
      # A crippled container (eg fork-bomb) will
      # likely not be running causing the [docker exec]
      # to fail so you cannot use shell.assert() here.
      _stdout,_stderr,status = shell.exec(docker_tar_pipe)
      if status == 0
        read_from(tmp_dir + sandbox_dir)
      else
        {}
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # red-amber-green colour of stdout,stderr,status
  # - - - - - - - - - - - - - - - - - - - - - -

  def set_colour
    if @timed_out
      @colour = 'timed_out'
    else
      @colour = red_amber_green
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def red_amber_green
    # @stdout and @stderr have been sanitized.
    rag_lambda = @cache.rag_lambda(image_name) { get_rag_lambda }
    colour = rag_lambda.call(@stdout, @stderr, @status)
    unless [:red,:amber,:green].include?(colour)
      log << rag_message(colour.to_s)
      colour = :amber
    end
    colour.to_s
  rescue => error
    log << rag_message(error.message)
    'amber'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def get_rag_lambda
    # In a crippled container (eg fork-bomb)
    # the shell.assert will mostly likely raise.
    cmd = 'cat /usr/local/bin/red_amber_green.rb'
    docker_cmd = "docker exec #{container_name} bash -c '#{cmd}'"
    src = shell.assert(docker_cmd)
    eval(src)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def rag_message(msg)
    "red_amber_green lambda error mapped to :amber\n#{msg}"
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
      # [ulimit data] prevents clang's
      # -fsanitize=address option.
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

  # - - - - - - - - - - - - - - - - - - - - - -
  # avatar
  # - - - - - - - - - - - - - - - - - - - - - -

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

  # - - - - - - - - - - - - - - - - - - - - - -
  # helpers
  # - - - - - - - - - - - - - - - - - - - - - -

  include StringCleaner
  include StringTruncater

  def sanitized(string)
    truncated(cleaned(string))
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def space
    ' '
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # externals
  # - - - - - - - - - - - - - - - - - - - - - -

  def disk
    @external.disk
  end

  def log
    @external.log
  end

  def shell
    @external.shell
  end

end

# - - - - - - - - - - - - - - - - - - - - - - - -
# The implementation of run cyber-dojo.sh is
#   o) create copies of all files in /tmp on host
#   o) one tar-pipe copies /tmp files into the container
#   o) run cyber-dojo.sh inside the container
#   0) ...
#
# An alternative implementation is
#   o) don't create copies of files off /tmp
#   o) N tar-pipes for N files, each copying directly into the container
#   o) run cyber-dojo.sh inside the container
#
# If only one file has changed you might imagine this is
# quicker but testing shows its actually a bit slower.
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
