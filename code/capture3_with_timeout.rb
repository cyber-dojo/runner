# frozen_string_literal: true
require 'timeout'

class Capture3WithTimeout
  # Based on https://gist.github.com/pasela/9392115

  def initialize(context)
    @process  = context.process
    @threader = context.threader
    @pipes = make_pipes(context.piper)
    @stdout_reader = ThreadNilValue.new
    @stderr_reader = ThreadNilValue.new
    @waiter = ThreadNilValue.new
    @pid = nil
  end

  # - - - - - - - - - - - - - - - - - -

  def run(max_seconds, command, tgz_in)
    result = { timed_out:false }
    begin
      Timeout.timeout(max_seconds) do
        result[:status] = inner_run(command, tgz_in)
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
  attr_reader :stdout_reader, :stderr_reader, :waiter
  attr_reader :pid

  # - - - - - - - - - - - - - - - - - -

  def make_pipes(piper)
    pipes = {
       stdin:piper.io,
      stdout:piper.io, # multiplexed cyber-dojo.sh's stdout/stderr/status
      stderr:piper.io
    }
    pipes[:stdout].in.binmode
    pipes[:stderr].in.binmode
    pipes[:stdin].out.binmode
    pipes[:stdin].out.sync = true
    pipes
  end

  # - - - - - - - - - - - - - - - - - -

  def inner_run(command, tgz_in)
    @pid = process.spawn(command, {
      pgroup:true, # make a new process group
          in: pipes[:stdin].in,
         out: pipes[:stdout].out,
         err: pipes[:stderr].out
    })
    @waiter = process.detach(pid) # prevent zombie child processes
    pipes[:stdin].in.close
    pipes[:stdout].out.close
    pipes[:stderr].out.close
    @stdout_reader = threader.thread { pipes[:stdout].in.read }
    @stderr_reader = threader.thread { pipes[:stderr].in.read }
    pipes[:stdin].out.write(tgz_in)
    pipes[:stdin].out.close
    @waiter.value
  end

  # - - - - - - - - - - - - - - - - - -

  def kill_process_group
    unless pid.nil?
      process.kill(:TERM, -pid)
      unless waiter.join(1)
        # join returned nil indicating the
        # process.kill(:TERM,-pid) was insufficient
        process.kill(:KILL, -pid)
      end
    end
  end

  # - - - - - - - - - - - - - - - - - -

  def gather_stdout_stderr_status(result)
    result[:status] = waiter.value
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

  def close_pipe(out)
    unless out.closed?
      out.close
    end
  end

  # - - - - - - - - - - - - - - - - - -

  class ThreadNilValue # Null-Object pattern
    def value
      nil
    end
  end

end
