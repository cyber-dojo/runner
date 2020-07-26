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
      stub(:red)
      run_cyber_dojo_sh
      assert red?, run_result
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd57', %w( amber ) do
      stub(:amber)
      run_cyber_dojo_sh_with_edit('Hiker.cs', 'return 6 * 9', 'return 6 * 9s')
      assert amber?, run_result
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd58', %w( green ) do
      stub(:green)
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

    def stub(colour)
      mx_stderr = CSHARP_NUNIT_STDERR[colour]
      if on_client?
        # :nocov_server:
        set_context
        # :nocov_server:
      end
      if on_server?
        # :nocov_client:
        stdout_tgz = TGZ.of({'stderr' => mx_stderr})
        set_context(
          sheller:sheller=BashShellerStub.new,
          logger:StdoutLoggerSpy.new,
          piper:piper=PiperStub.new(stdout_tgz),
          process:process=ProcessSpawnerStub.new
        )
        puller.add(image_name)
        process.spawn {}
        process.detach { ThreadStub.new(0) }
        process.kill {}
        command = "docker run --rm --entrypoint=cat #{image_name} /usr/local/bin/red_amber_green.rb"
        sheller.capture(command) {
          stdout = "lambda{|stdout,stderr,status| '#{colour}' }"
          [stdout,stderr='',status=0]
        }
        # :nocov_client:
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
