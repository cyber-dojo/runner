# frozen_string_literal: true
require 'timeout'

# [X] See comments at the end of file.

class Capture3WithTimeout

  def initialize(context)
    @process  = context.process
    @threader = context.threader
    @pipes = make_binary_pipes(context.piper)
    @stdout_reader = ThreadNilValue.new
    @stderr_reader = ThreadNilValue.new
    @command_waiter = ThreadNilValue.new
    @pid = nil
  end

  # - - - - - - - - - - - - - - - - - -

  def run(max_seconds, command, tgz_in)
    result = { timed_out:false }
    begin
      Timeout.timeout(max_seconds) do
        result[:status] = spawn_detached_process(command, tgz_in)
      end
    rescue Timeout::Error
      result[:timed_out] = true
      kill_process_group
      yield
    ensure
      gather_stdout_stderr_status(result)
      close_pipes
    end
    result
  end

  private

  attr_reader :process, :threader, :pipes
  attr_reader :stdout_reader, :stderr_reader, :command_waiter
  attr_reader :pid

  # - - - - - - - - - - - - - - - - - -

  def make_binary_pipes(piper)
    pipes = {
      stdin:piper.make,
      stdout:piper.make, # [X]
      stderr:piper.make
    }
    pipes[:stdout].in.binmode
    pipes[:stderr].in.binmode
    pipes[:stdin].out.binmode
    pipes[:stdin].out.sync = true
    pipes
  end

  # - - - - - - - - - - - - - - - - - -

  def spawn_detached_process(command, tgz_in)
    @pid = process.spawn(command, {
      pgroup:true, # [X] process group
          in: pipes[:stdin].in,
         out: pipes[:stdout].out,
         err: pipes[:stderr].out
    })
    @command_waiter = process.detach(pid) # [X]
    pipes[:stdin].in.close
    pipes[:stdout].out.close
    pipes[:stderr].out.close
    @stdout_reader = threader.thread('reads-stdout') {
      pipes[:stdout].in.read
    }
    @stderr_reader = threader.thread('reads-stderr') {
      pipes[:stderr].in.read
    }
    pipes[:stdin].out.write(tgz_in)
    pipes[:stdin].out.close
    command_waiter.value
  end

  # - - - - - - - - - - - - - - - - - -

  def kill_process_group
    unless pid.nil?
      process.kill(:TERM, -pid)
      unless command_waiter.join(1)
        # join failed (returned nil) indicating the
        # process.kill(:TERM,-pid) was ignored, so...
        process.kill(:KILL, -pid)
      end
    end
  end

  # - - - - - - - - - - - - - - - - - -

  def gather_stdout_stderr_status(result)
    result[:status] = command_waiter.value
    result[:stdout] = stdout_reader.value
    result[:stderr] = stderr_reader.value
  end

  # - - - - - - - - - - - - - - - - - -

  def close_pipes
    close_pipe(pipes[:stdin].in)
    close_pipe(pipes[:stdout].out)
    close_pipe(pipes[:stderr].out)
  end

  # - - - - - - - - - - - - - - - - - -

  def close_pipe(pipe_end)
    unless pipe_end.closed?
      pipe_end.close
    end
  end

  # - - - - - - - - - - - - - - - - - -

  class ThreadNilValue # Null-Object pattern
    def value
      nil
    end
  end

end

=begin

The documentation for Ruby's Process.detach()
See
https://apidock.com/ruby/Process/detach/class
reads...

  Some operating systems retain the status of terminated
  child processes until the parent collects that status
  (normally using some variant of wait()). If the parent
  never collects this status, the child stays around as a
  zombie process. Process::detach prevents this by setting
  up a separate Ruby thread whose sole job is to reap the
  status of the process pid when it terminates. Use detach
  only when you do not intend to explicitly wait for the
  child to terminate.

We are not calling wait(), we are using Timeout.timeout()
instead. So we need to call Process.detach(). The
documentation for Process.detach() continues...

  The waiting thread returns the exit status of the
  detached process when it terminates, so you can use
  Thread#join to know the result.

The documentation for Ruby's Thread.value
See
https://ruby-doc.org/core-2.5.0/Thread.html#method-i-value
reads...

  Waits for thr to complete,
  using join,
  and returns its value ...

So, the line

  result[:status] = waiter.value

sets the exit status of the detached "docker run ...".
What is the exit-status of a docker-run command?
See
https://docs.docker.com/engine/reference/run/#exit-status

  When docker run exits with a non-zero code, the exit
  codes follow the chroot standard, see below:
    125 if the error is with Docker daemon itself
    126 if the contained command cannot be invoked
    127 if the contained command cannot be found
    Exit code of contained command otherwise

So, the docker run command is...

  bash -c 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'

The first part untars the tgz stream of files from the
browser (as well as ~/cyber_dojo_main.sh and some other
helper scripts) into the home dir of the sandbox user.
The second part runs cyber_dojo_main.sh (see home_files.rb)
So the exit status will be the exit status of the last
command of cyber_dojo_main.sh which is the last command of
the trap handler, which is the last command of the
send_tgz() function, which is...

  gzip  < "${TAR_FILE}"

The important point is this: the exit status is *not* the
exit status of cyber-dojo.sh, it is the exit status of
the machinery in cyber_dojo_main.sh, which multiplexes
cyber-dojo.sh's stdout/stderr/status on stdout of the
container.

Useful:
https://gist.github.com/pasela/9392115

=end
