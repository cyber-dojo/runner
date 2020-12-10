# frozen_string_literal: true
require 'timeout'

class Capture3WithTimeout
  # Based on https://gist.github.com/pasela/9392115

  def initialize(context)
    @process  = context.process
    @threader = context.threader

    @stdin_pipe = context.piper.io
    @stdin_pipe.out.binmode
    @stdin_pipe.out.sync = true

    @stdout_pipe = context.piper.io # multiplexed cyber-dojo.sh's stdout/stderr/status
    @stdout_pipe.in.binmode

    @stderr_pipe = context.piper.io
    @stderr_pipe.in.binmode
  end

  def run(command, max_seconds, tgz_in)
    result = { timed_out:false }

    stdout_reader_thread = ThreadNilValue.new
    stderr_reader_thread = ThreadNilValue.new
    wait_thread = ThreadNilValue.new

    pid = nil

    begin
      Timeout.timeout(max_seconds) do
        pid = @process.spawn(command, {
          pgroup:true, # make a new process group
              in: @stdin_pipe.in,
             out: @stdout_pipe.out,
             err: @stderr_pipe.out
        })
        wait_thread = @process.detach(pid) # prevent zombie child processes
        @stdin_pipe.in.close
        @stdout_pipe.out.close
        @stderr_pipe.out.close
        stdout_reader_thread = @threader.thread { @stdout_pipe.in.read }
        stderr_reader_thread = @threader.thread { @stderr_pipe.in.read }
        @stdin_pipe.out.write(tgz_in)
        @stdin_pipe.out.close
        result[:status] = wait_thread.value
      end
    rescue Timeout::Error
      result[:timed_out] = true
      unless pid.nil?
        @process.kill(:TERM, -pid)
        if wait_thread.join(1).nil?
          # process.kill(:TERM,-pid) did not return after 1 second
          @process.kill(:KILL, -pid)
        end
      end
      yield
    ensure
      result[:status] = wait_thread.value
      result[:stdout] = stdout_reader_thread.value
      result[:stderr] = stderr_reader_thread.value
      safe_close(@stdout_pipe.out)
      safe_close(@stderr_pipe.out)
    end

    result
  end

  private

  def safe_close(out)
    unless out.closed?
      out.close
    end
  end

  class ThreadNilValue
    def value
      nil
    end
  end

end
