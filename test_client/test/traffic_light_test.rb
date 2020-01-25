# frozen_string_literal: true
require_relative 'test_base'

class TrafficLightTest < TestBase

  def self.hex_prefix
    'FAA'
  end

  # - - - - - - - - - - - - - - - - -

  test '3DA', '[C,assert] test with red traffic-light' do
    expected_stdout = ''
    expected_stderr = [
      "test: hiker.tests.c:6: life_the_universe_and_everything: Assertion `answer() == 42' failed.",
      "make: *** [makefile:19: test.output] Aborted"
    ].join("\n")
    expected_status = 2

    run_cyber_dojo_sh
    assert_equal 'red', traffic_light
    diagnostic = 'stdout is not empty!'
    assert_equal expected_stdout, stdout, diagnostic
    diagnostic = "Expected stderr to start with #{expected_stderr}"
    assert stderr.start_with?(expected_stderr), diagnostic
    assert_equal expected_status, status, :status
  end

  # - - - - - - - - - - - - - - - - -

  test '3DB', '[C,assert] test with amber traffic-light' do
    expected_stdout = ''
    expected_stderr = [
      'hiker.c:5:16: error: invalid suffix "sd" on integer constant',
      'hiker.c:6:1: warning: control reaches end of non-void function [-Wreturn-type]',
      "make: *** [makefile:22: test] Error 1"
    ]
    expected_status = 2

    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => hiker_c.sub('6 * 9', '6 * 9sd')
      }
    })
    assert_equal 'amber', traffic_light
    assert_equal expected_stdout, stdout, :stdout
    expected_stderr.each do |line|
      diagnostic = "Expected stderr to include the line #{line}\n#{stderr}"
      assert stderr.include?(line), diagnostic
    end
    assert_equal expected_status, status
  end

  # - - - - - - - - - - - - - - - - -

  test '3DC', '[C,assert] test with green traffic-light' do
    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => hiker_c.sub('6 * 9', '6 * 7')
      }
    })
    assert_equal 'green', traffic_light, result
    assert stdout.include?('GCC Code Coverage Report'), result
    assert_equal '', stderr
    assert_equal 0, status
  end

end
