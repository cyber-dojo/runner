# [X] See comments at the end of file.
class Capture3WithTimeout
  def initialize(context, container_name)
    @context = context
    @container_name = container_name
    @piper = context.piper
    @process  = context.process
    @threader = context.threader
  end

  # - - - - - - - - - - - - - - - - - -

  def run(command, max_seconds, tgz_in)
    result = { timed_out: false }
    pipes = make_binary_pipes
    stdout_reader = threaded('stdout-reader') { pipes[:stdout].in.read }
    stderr_reader = threaded('stderr-reader') { pipes[:stderr].in.read }
    begin
      pid, waiter = spawn_detached_process(command, pipes, tgz_in)
      # join answers nil when max_seconds runs out with the CLI still alive.
      if waiter.join(max_seconds).nil?
        result[:timed_out] = true
        result[:docker_stop] = docker_stop
        kill_cli_unless_stop_released_it(waiter, pid)
      end
      result[:status] = waiter.value
      result[:stdout] = stdout_reader.value
      result[:stderr] = stderr_reader.value
    ensure
      close_pipe(pipes[:stdin].in)
      close_pipe(pipes[:stdout].out)
      close_pipe(pipes[:stderr].out)
    end
    result
  end

  private

  attr_reader :context, :container_name, :piper, :process, :threader

  STOP_SECONDS = 1
  GRACE_SECONDS = 10

  # The backstop for a docker stop that does not take effect, eg the daemon is
  # unresponsive. Without it waiter.value waits for ever. A stopped container
  # releases the CLI in about 25ms, so exhausting the grace means something is
  # wrong rather than slow.
  # See docs/profiling/time_docker_stop_alone_to_cli_exit.rb
  def kill_cli_unless_stop_released_it(waiter, pid)
    return unless waiter.join(GRACE_SECONDS).nil?

    process.kill(:KILL, pid)
  end

  def make_binary_pipes
    pipes = { stdin: piper.make, stdout: piper.make, stderr: piper.make }
    pipes[:stdout].in.binmode
    pipes[:stderr].in.binmode
    pipes[:stdin].out.binmode
    pipes[:stdin].out.sync = true
    pipes
  end

  # - - - - - - - - - - - - - - - - - -

  def threaded(name, &block)
    threader.thread(name, &block)
  end

  # - - - - - - - - - - - - - - - - - -

  def spawn_detached_process(command, pipes, tgz_in)
    pid = process.spawn(command, {
                          in: pipes[:stdin].in,
                          out: pipes[:stdout].out,
                          err: pipes[:stderr].out
                        })
    waiter = process.detach(pid) # [X]
    pipes[:stdin].in.close
    pipes[:stdout].out.close
    pipes[:stderr].out.close
    pipes[:stdin].out.write(tgz_in)
    pipes[:stdin].out.close
    [pid, waiter]
  end

  # - - - - - - - - - - - - - - - - - -

  # Stopping the container is what ends a timed-out run. When the container
  # stops, [docker run] exits, its stdout closes, and the readers complete.
  # --time 1 is SIGTERM and then SIGKILL a second later, so cyber-dojo.sh's
  # own EXIT trap still gets its chance to run.
  # See docs/profiling/time_docker_stop_alone_to_cli_exit.rb
  def docker_stop
    command = "docker stop --time #{STOP_SECONDS} #{container_name}"
    stdout, stderr, status = context.sheller.capture(command)
    {
      command: command,
      stdout: stdout,
      stderr: stderr,
      status: status
    }
  end

  # - - - - - - - - - - - - - - - - - -

  def close_pipe(pipe_end)
    return if pipe_end.closed?

    pipe_end.close
  end
end

#
# The documentation for Ruby's Process.detach()
# See
# https://apidock.com/ruby/Process/detach/class
# reads...
#
#   Some operating systems retain the status of terminated
#   child processes until the parent collects that status
#   (normally using some variant of wait()). If the parent
#   never collects this status, the child stays around as a
#   zombie process. Process::detach prevents this by setting
#   up a separate Ruby thread whose sole job is to reap the
#   status of the process pid when it terminates. Use detach
#   only when you do not intend to explicitly wait for the
#   child to terminate.
#
# We are not calling wait(), we are bounding the wait with
# Thread#join(max_seconds) instead. So we need to call
# Process.detach(), whose documentation continues...
#
#   The waiting thread returns the exit status of the
#   detached process when it terminates, so you can use
#   Thread#join to know the result.
#
# The documentation for Ruby's Thread.value
# See
# https://ruby-doc.org/core-2.5.0/Thread.html#method-i-value
# reads...
#
#   Waits for thr to complete,
#   using join,
#   and returns its value ...
#
# So, the lines
#
#   result[:status] = waiter.value
#
# sets the exit status of the detached "docker run ...".
# What is the exit-status of a docker-run command?
# See
# https://docs.docker.com/engine/reference/run/#exit-status
#
#   When docker run exits with a non-zero code, the exit
#   codes follow the chroot standard, see below:
#     125 if the error is with Docker daemon itself
#     126 if the contained command cannot be invoked
#     127 if the contained command cannot be found
#     Exit code of contained command otherwise
#
# So, the docker run command is...
#
#   bash -c 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'
#
# The first part untars the tgz stream of files from the
# browser (as well as ~/cyber_dojo_main.sh and some other
# helper scripts) into the home dir of the sandbox user.
# The second part runs cyber_dojo_main.sh (see home_files.rb)
# So the exit status will be the exit status of the last
# command of cyber_dojo_main.sh which is
#
#   printf $? > "${TMP_DIR}/status"
#
# The important point is this: the exit status of
# waiter.value is *not* the exit status of cyber-dojo.sh,
# it is the exit status of the machinery in cyber_dojo_main.sh,
# which multiplexes cyber-dojo.sh's stdout/stderr/status
# and text files, on stdout of the container.
#
# Useful:
# https://gist.github.com/pasela/9392115
#
