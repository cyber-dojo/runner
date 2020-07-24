# frozen_string_literal: true
require 'ostruct'
require 'timeout'

module Capture3WithTimeout

  def capture3_with_timeout(context, command, spawn_opts)
    # Based on https://gist.github.com/pasela/9392115
    opts = {
      stdin_data: spawn_opts.delete(:stdin_data) || '',
         binmode: spawn_opts.delete(:binmode) || false,
         timeout: spawn_opts.delete(:timeout),
          signal: spawn_opts.delete(:signal) || :TERM,
      kill_after: spawn_opts.delete(:kill_after),
    }

    stdin_pipe  = in_out_pipe
    stdout_pipe = in_out_pipe
    stderr_pipe = in_out_pipe
    stdin_pipe.out.sync = true

    if opts[:binmode]
      stdin_pipe.out.binmode
      stdout_pipe.in.binmode
      stderr_pipe.in.binmode
    end

    spawn_opts[:in]  = stdin_pipe.in
    spawn_opts[:out] = stdout_pipe.out
    spawn_opts[:err] = stderr_pipe.out

    stdout_reader_thr = nil
    stderr_reader_thr = nil
    wait_thr = nil

    process = context.process
    threader = context.threader

    result = {
      status:nil, # of command
      stdout:'',  # of command (multiplexed cyber-dojo.sh's stdout/stderr/status)
      stderr:'',  # of command
      pid:nil
    }

    begin
      result[:timed_out] = false
      Timeout.timeout(opts[:timeout]) do
        result[:pid] = process.spawn(command, spawn_opts)
        wait_thr = process.detach(result[:pid])
        stdin_pipe.in.close
        stdout_pipe.out.close
        stderr_pipe.out.close
        stdout_reader_thr = threader.thread { stdout_pipe.in.read }
        stderr_reader_thr = threader.thread { stderr_pipe.in.read }
        stdin_pipe.out.write(opts[:stdin_data])
        stdin_pipe.out.close
        result[:status] = wait_thr.value
      end
    rescue Timeout::Error
      result[:timed_out] = true
      unless result[:pid]
        pid = spawn_opts[:pgroup] ? -result[:pid] : result[:pid]
        process.kill(opts[:signal], pid)
        if opts[:kill_after]
          unless wait_thr.join(opts[:kill_after])
            process.kill(:KILL, pid)
          end
        end
      end
      yield if block_given?
    ensure
      result[:status] = wait_thr.value if wait_thr
      result[:stdout] = stdout_reader_thr.value if stdout_reader_thr
      result[:stderr] = stderr_reader_thr.value if stderr_reader_thr
      stdout_pipe.out.close unless stdout_pipe.out.closed?
      stderr_pipe.out.close unless stderr_pipe.out.closed?
    end

    result.delete(:pid)

    result
  end

  # - - - - - - - - - - - - - - - - - - - -

  def in_out_pipe
    In_Out_Pipe.new(*IO.pipe)
  end

  In_Out_Pipe = Struct.new(:in, :out)

end
