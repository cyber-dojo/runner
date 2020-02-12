# frozen_string_literal: true
require_relative 'test_base'

class TrafficLightTest < TestBase

  def self.id58_prefix
    'FAA'
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DA', 'test with red traffic-light' do
    red_traffic_light_test
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DB', 'test with amber traffic-light' do
    amber_traffic_light_test
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DC', 'test with green traffic-light' do
    green_traffic_light_test
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DD', 'test red/amber/green in parallel threads' do
    rag1 = in_parallel_red_amber_green
    rag2 = in_parallel_red_amber_green
    rag3 = in_parallel_red_amber_green
    rag3.each{|t| t.join}
    rag2.each{|t| t.join}
    rag1.each{|t| t.join}
  end

  def in_parallel_red_amber_green
    red = Thread.new { red_traffic_light_test }
    amber = Thread.new { amber_traffic_light_test }
    green = Thread.new { green_traffic_light_test }
    [red,amber,green]
  end

  private

  def red_traffic_light_test
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

  def amber_traffic_light_test
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

  def green_traffic_light_test
    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => hiker_c.sub('6 * 9', '6 * 7')
      }
    })
    assert_equal 'green', traffic_light, result
    assert_equal '', stderr
    assert_equal 0, status
  end

end
