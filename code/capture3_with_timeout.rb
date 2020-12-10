# frozen_string_literal: true
require 'timeout'

class Capture3WithTimeout
  # Based on https://gist.github.com/pasela/9392115

  def initialize(context)
    @process  = context.process
    @threader = context.threader
    @pipes = {
      stdin:context.piper.io,
      stdout:context.piper.io, # multiplexed cyber-dojo.sh's stdout/stderr/status
      stderr:context.piper.io
    }
    @pipes[:stdout].in.binmode
    @pipes[:stderr].in.binmode
    @pipes[:stdin].out.binmode
    @pipes[:stdin].out.sync = true
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
              in: @pipes[:stdin].in,
             out: @pipes[:stdout].out,
             err: @pipes[:stderr].out
        })
        wait_thread = @process.detach(pid) # prevent zombie child processes
        @pipes[:stdin].in.close
        @pipes[:stdout].out.close
        @pipes[:stderr].out.close
        stdout_reader_thread = @threader.thread { @pipes[:stdout].in.read }
        stderr_reader_thread = @threader.thread { @pipes[:stderr].in.read }
        @pipes[:stdin].out.write(tgz_in)
        @pipes[:stdin].out.close
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
      safe_close(@pipes[:stdout].out)
      safe_close(@pipes[:stderr].out)
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
