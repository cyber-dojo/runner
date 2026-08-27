require_relative '../test_base'
require_server_code 'tgz'
require_server_code 'tarfile_writer'

module Dual
  class RunRedAmberGreenTest < TestBase

    c_assert_test 'c7Bd56', %w[red] do
      stub(:red)
      run_cyber_dojo_sh
      assert red?, run_result
      on_client do
        # simplecov:disable
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
        # simplecov:enable
      end
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test 'c7Bd57', %w[amber] do
      stub(:amber)
      run_cyber_dojo_sh_with_edit('hiker.c', '6 * 9', '6 * 9s')
      assert amber?, run_result
      on_client do
        # simplecov:disable
        expected_stdout = ''
        expected_stderr = [
          "hiker.c:5:16: error: invalid suffix 's' on integer constant",
          'make: *** [makefile:22: test] Error 1'
        ]
        expected_status = '2'

        assert_equal expected_stdout, stdout, :stdout
        expected_stderr.each do |line|
          diagnostic = "Expected stderr to include the line #{line}\n#{stderr}"
          assert stderr.include?(line), diagnostic
        end
        assert_equal expected_status, status, :status
        # simplecov:enable
      end
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test 'c7Bd58', %w[green] do
      stub(:green)
      run_cyber_dojo_sh_with_edit('hiker.c', '6 * 9', '6 * 7')
      assert green?, run_result
      on_client do
        # simplecov:disable
        assert_equal "All tests passed\n", stdout
        expected_stderr =
          "(INFO) Reading coverage data...\n" \
          "(INFO) Writing coverage report...\n"
        assert_equal expected_stderr, stderr
        assert_equal '0', status
        # simplecov:enable
      end
    end

    private

    def stub(colour)
      on_client do
        # simplecov:disable
        set_context
        # simplecov:enable
      end
      on_server do
        # simplecov:disable
        stdout_tgz = TGZ.of({ 'stderr' => 'any' })
        # The rag-lambda arrives as a tar, being what the daemon's archive
        # endpoint answers when TrafficLight reads it out of the image.
        tar = TarFile::Writer.new
        tar.write('red_amber_green.rb', "lambda{|stdout,stderr,status| '#{colour}' }")
        set_context(
          logger: StdoutLoggerSpy.new,
          daemon: DaemonStub.new(stdout: stdout_tgz, archive: tar.tar_file)
        )
        puller.add(image_name)
        # simplecov:enable
      end
    end

    # - - - - - - - - - - - - - - - - -

    def run_cyber_dojo_sh_with_edit(filename, from, to)
      file = starting_files[filename]
      run_cyber_dojo_sh({
                          changed: { filename => file.sub(from, to) },
                          max_seconds: 5
                        })
    end
  end
end
