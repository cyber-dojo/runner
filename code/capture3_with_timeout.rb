# frozen_string_literal: true
require 'timeout'

module Capture3WithTimeout

  def capture3_with_timeout(context, command, max_seconds, tgz_in)
    # Based on https://gist.github.com/pasela/9392115
    result = { timed_out:false }

    piper    = context.piper
    process  = context.process
    threader = context.threader

    stdin_pipe = piper.io
    stdin_pipe.out.binmode
    stdin_pipe.out.sync = true

    stdout_pipe = piper.io # multiplexed cyber-dojo.sh's stdout/stderr/status
    stdout_pipe.in.binmode

    stderr_pipe = piper.io
    stderr_pipe.in.binmode

    stdout_reader_thread = ThreadNullValue.new('')
    stderr_reader_thread = ThreadNullValue.new('')
    wait_thread = ThreadNullValue.new(nil)

    pid = nil

    begin
      Timeout.timeout(max_seconds) do
        pid = process.spawn(command, {
          pgroup:true, # make a new process group
              in: stdin_pipe.in,
             out: stdout_pipe.out,
             err: stderr_pipe.out
        })
        wait_thread = process.detach(pid)
        stdin_pipe.in.close
        stdout_pipe.out.close
        stderr_pipe.out.close
        stdout_reader_thread = threader.thread { stdout_pipe.in.read }
        stderr_reader_thread = threader.thread { stderr_pipe.in.read }
        stdin_pipe.out.write(tgz_in)
        stdin_pipe.out.close
        result[:status] = wait_thread.value
      end
    rescue Timeout::Error
      result[:timed_out] = true
      unless pid.nil?
        process.kill(:TERM, -pid)
        unless wait_thread.join(1)
          process.kill(:KILL, -pid)
        end
      end
      yield
    ensure
      result[:status] = wait_thread.value
      result[:stdout] = stdout_reader_thread.value
      result[:stderr] = stderr_reader_thread.value
      safe_close(stdout_pipe.out)
      safe_close(stderr_pipe.out)
    end

    result
  end

  def safe_close(out)
    out.close unless out.closed?
  end

  class ThreadNullValue
    def initialize(value)
      @value = value
    end
    attr_reader :value
  end

end
