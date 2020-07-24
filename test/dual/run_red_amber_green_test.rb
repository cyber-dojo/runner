# frozen_string_literal: true
require_relative '../test_base'
require_server_source 'tgz'

module Dual
  class RunRedAmberGreenTest < TestBase

    def self.id58_prefix
      'c7B'
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd56', %w( red ) do
      on_server_stub(CSHARP_NUNIT_STDERR[:red])
      run_cyber_dojo_sh
      assert red?, run_result
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd57', %w( amber ) do
      on_server_stub(CSHARP_NUNIT_STDERR[:amber])
      run_cyber_dojo_sh_with_edit('Hiker.cs', 'return 6 * 9', 'return 6 * 9s')
      assert amber?, run_result
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd58', %w( green ) do
      on_server_stub(CSHARP_NUNIT_STDERR[:green])
      run_cyber_dojo_sh_with_edit('Hiker.cs', 'return 6 * 9', 'return 6 * 7')
      assert green?, run_result
    end

    private

    CSHARP_NUNIT_STDERR = {
        red:'Test Count: 3, Passed: 2, Failed: 1, Warnings: 0, Inconclusive: 0, Skipped: 0',
      amber:'sdfgsdfgsdfgsdfg',
      green:'Test Count: 3, Passed: 3, Failed: 0, Warnings: 0, Inconclusive: 0, Skipped: 0'
    }

    # - - - - - - - - - - - - - - - - -

    def on_server_stub(mx_stderr)
      if on_server?
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

    # - - - - - - - - - - - - - - - - -

    class ThreadStub
      def initialize(name, value)
        @name = name
        @value = value
      end
      def value
        @value
      end
    end

    # - - - - - - - - - - - - - - - - -

    def run_cyber_dojo_sh_with_edit(filename, from, to)
      file = starting_files[filename]
      run_cyber_dojo_sh({
        changed: { filename => file.sub(from, to) },
        max_seconds: 3
      })
    end

  end
end
