# frozen_string_literal: true
require 'timeout'

module Capture3WithTimeout

  def capture3_with_timeout(context, command, max_seconds, tgz_in)
    # Based on https://gist.github.com/pasela/9392115
    piper    = context.piper
    process  = context.process
    threader = context.threader

    stdin_pipe  = piper.io
    stdin_pipe.out.binmode
    stdin_pipe.out.sync = true

    stdout_pipe = piper.io
    stdout_pipe.in.binmode

    stderr_pipe = piper.io
    stderr_pipe.in.binmode

    stdout_reader_thr = nil
    stderr_reader_thr = nil
    wait_thr = nil

    result = {
      timed_out:false,
      status:nil, # of command
      stdout:'',  # of command (multiplexed cyber-dojo.sh's stdout/stderr/status)
      stderr:'',  # of command
    }

    pid = nil

    begin
      Timeout.timeout(max_seconds) do
        pid = process.spawn(command, {
          pgroup:true, # make a new process group
              in: stdin_pipe.in,
             out: stdout_pipe.out,
             err: stderr_pipe.out
        })
        wait_thr = process.detach(pid)
        stdin_pipe.in.close
        stdout_pipe.out.close
        stderr_pipe.out.close
        stdout_reader_thr = threader.thread { stdout_pipe.in.read }
        stderr_reader_thr = threader.thread { stderr_pipe.in.read }
        stdin_pipe.out.write(tgz_in)
        stdin_pipe.out.close
        result[:status] = wait_thr.value
      end
    rescue Timeout::Error
      result[:timed_out] = true
      unless pid.nil?
        process.kill(:TERM, -pid)
        unless wait_thr.join(1)
          process.kill(:KILL, -pid)
        end
      end
      yield
    ensure
      result[:status] = wait_thr.value if wait_thr
      result[:stdout] = stdout_reader_thr.value if stdout_reader_thr
      result[:stderr] = stderr_reader_thr.value if stderr_reader_thr
      stdout_pipe.out.close unless stdout_pipe.out.closed?
      stderr_pipe.out.close unless stderr_pipe.out.closed?
    end

    result
  end

end
