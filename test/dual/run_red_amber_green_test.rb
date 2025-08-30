# frozen_string_literal: true
require_relative '../test_base'
require_server_code 'tgz'

module Dual
  class RunRedAmberGreenTest < TestBase
    def self.id58_prefix
      'c7B'
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test 'd56', %w[red] do
      stub(:red)
      run_cyber_dojo_sh
      assert red?, run_result
      on_client do
        # :nocov_server:
        expected_stdout = ''
        expected_stderr = [
          'Assertion failed: answer() == 42 (hiker.tests.c: life_the_universe_and_everything: 7)',
          'make: *** [makefile:19: test.output] Aborted'
        ]
        expected_status = '2'

        assert_equal expected_stdout, stdout, :stdout
        expected_stderr.each do |line|
          diagnostic = "Expected stderr to include the line #{line}\n#{stderr}"
          assert stderr.include?(line), diagnostic
        end
        assert_equal expected_status, status, :status
        # :nocov_server:
      end
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test 'd57', %w[amber] do
      stub(:amber)
      run_cyber_dojo_sh_with_edit('hiker.c', '6 * 9', '6 * 9s')
      assert amber?, run_result
      on_client do
        # :nocov_server:
        expected_stdout = ''
        expected_stderr = [
          'hiker.c:5:16: error: invalid suffix "s" on integer constant',
          'hiker.c:6:1: warning: control reaches end of non-void function [-Wreturn-type]',
          'make: *** [makefile:22: test] Error 1'
        ]
        expected_status = '2'

        assert_equal expected_stdout, stdout, :stdout
        expected_stderr.each do |line|
          diagnostic = "Expected stderr to include the line #{line}\n#{stderr}"
          assert stderr.include?(line), diagnostic
        end
        assert_equal expected_status, status, :status
        # :nocov_server:
      end
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test 'd58', %w[green] do
      stub(:green)
      run_cyber_dojo_sh_with_edit('hiker.c', '6 * 9', '6 * 7')
      assert green?, run_result
      on_client do
        # :nocov_server:
        assert_equal "All tests passed\n", stdout
        expected_stderr =
          "(INFO) Reading coverage data...\n" +
          "(INFO) Writing coverage report...\n"
        assert_equal expected_stderr, stderr
        assert_equal '0', status
        # :nocov_server:
      end
    end

    private

    def stub(colour)
      on_client do
        # :nocov_server:
        set_context
        # :nocov_server:
      end
      on_server do
        # :nocov_client:
        stdout_tgz = TGZ.of({ 'stderr' => 'any' })
        set_context(
          logger: StdoutLoggerSpy.new,
          piper: piper = PipeMakerStub.new(stdout_tgz),
          process: process = ProcessSpawnerStub.new,
          sheller: sheller = BashShellerStub.new
        )
        puller.add(image_name)
        process.spawn {}
        process.detach { ThreadValueStub.new(0) }
        process.kill {}
        command = "docker run --rm --entrypoint=cat #{image_name} /usr/local/bin/red_amber_green.rb"
        sheller.capture(command) do
          stdout = "lambda{|stdout,stderr,status| '#{colour}' }"
          [stdout, stderr = '', status = 0]
        end
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
