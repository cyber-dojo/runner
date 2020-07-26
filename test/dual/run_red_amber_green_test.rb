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
      amber:'Hiker.cs(5,20): error CS1525: Unexpected symbol `s',
      green:'Test Count: 3, Passed: 3, Failed: 0, Warnings: 0, Inconclusive: 0, Skipped: 0'
    }

    # - - - - - - - - - - - - - - - - -

    def on_server_stub(mx_stderr)
      if on_server?
        stdout_tgz = TGZ.of({'stderr' => mx_stderr})
        stderr = ''
        set_context(
          logger:StdoutLoggerSpy.new,
          process:process=ProcessSpawnerStub.new,
          threader:ThreaderStub.new(stdout_tgz, stderr)
        )
        puller.add(image_name)
        tp = ProcessSpawner.new
        process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
        process.detach { |pid| tp.detach(pid); ThreadStub.new(0) }
        process.kill { |signal,pid| tp.kill(signal, pid) }
      end
    end

    # - - - - - - - - - - - - - - - - - - - - -

    def run_cyber_dojo_sh_with_edit(filename, from, to)
      file = starting_files[filename]
      run_cyber_dojo_sh({
        changed: { filename => file.sub(from, to) },
        max_seconds: 3
      })
    end

  end
end
