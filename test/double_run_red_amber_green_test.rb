# frozen_string_literal: true
require_relative 'test_base'
require_server_source 'tgz'

class DoubleRunRedAmberGreenTest < TestBase

  def self.id58_prefix
    'c7B'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  class StdoutStderrThreaderStub
    def initialize(stdout_tgz, stderr)
      @stdout_tgz = stdout_tgz
      @stderr = stderr
      @n = 0
    end
    def thread
      @n += 1
      if @n === 1
        return ThreadStub.new(:stdout, @stdout_tgz)
      end
      if @n === 2
        return ThreadStub.new(:stderr, @stderr)
      end
    end
  end

  class ThreadStub
    def initialize(name, value)
      @name = name
      @value = value
    end
    def value
      @value
    end
    def join(_secs)
      self
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'd56', %w( red ) do
    if ENV['CONTEXT'] === 'server'
      mx_stderr = 'Test Count: 3, Passed: 2, Failed: 1, Warnings: 0, Inconclusive: 0, Skipped: 0'
      stdout_tgz = TGZ.of({'stderr' => mx_stderr})
      stderr = ''
      @context = Context.new(
        logger:StdoutLoggerSpy.new,
        process:process=ProcessAdapterStub.new,
        threader:StdoutStderrThreaderStub.new(stdout_tgz, stderr)
      )
      puller.add(image_name)
      tp = ProcessAdapter.new
      process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
      process.detach { |pid| tp.detach(pid); ThreadStub.new(:status,0) }
      process.kill { |signal,pid| tp.kill(signal, pid) }
    end

    run_cyber_dojo_sh

    assert red?, run_result
  end

  # - - - - - - - - - - - - - - - - -


end
