# frozen_string_literal: true
require_relative 'test_base'

class TrafficLightTest < TestBase

  def self.id58_prefix
    'FAA'
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DA', 'red/amber/green traffic-light' do
    red_traffic_light_test
    amber_traffic_light_test
    green_traffic_light_test
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test '3DD', 'red/amber/green in parallel threads' do
    rag1 = in_parallel_red_amber_green
    rag2 = in_parallel_red_amber_green
    rag3 = in_parallel_red_amber_green
    rag3.each{ |t| t.join }
    rag2.each{ |t| t.join }
    rag1.each{ |t| t.join }
  end

  # - - - - - - - - - - - - - - - - -

  test '3DE', %w(
  given an image_name that does not have bash installed,
  then the colour is 'faulty',
  and log contains info as JSON object
  ) do
    no_bash = 'alpine:latest' # Must have been pulled onto node before runner-server started
    run_cyber_dojo_sh(image_name:no_bash)
    assert faulty?, run_result
    stderr = run_result['log']['stderr']
    stderr_pattern = /\[FATAL tini \(\d+\)\] exec bash failed: No such file or directory/
    assert stderr.match(stderr_pattern), stderr
  end

  private

  def in_parallel_red_amber_green
      red = Thread.new {   red_traffic_light_test }
    amber = Thread.new { amber_traffic_light_test }
    green = Thread.new { green_traffic_light_test }
    [red,amber,green]
  end

  def red_traffic_light_test
    run_cyber_dojo_sh
    assert red?, run_result
    diagnostic = 'stdout is not empty!'
    expected_stdout = ''
    assert_equal expected_stdout, stdout, diagnostic

    r = /test: hiker.tests.c:(\d+): life_the_universe_and_everything: Assertion `answer\(\) == 42' failed./
    diagnostic = "Expected stderr to match #{r.to_s}\nstderr:#{stderr}"
    assert r.match(stderr), diagnostic

    r = /make: \*\*\* \[makefile:(\d+): test.output\] Aborted/
    diagnostic = "Expected stderr to match #{r.to_s}\nstderr:#{stderr}"
    assert r.match(stderr), diagnostic

    expected_status = '2'
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
    expected_status = '2'

    run_cyber_dojo_sh(
      changed_files: {
        'hiker.c' => hiker_c.sub('6 * 9', '6 * 9sd')
      }
    )
    assert amber?, run_result
    assert_equal expected_stdout, stdout, :stdout
    expected_stderr.each do |line|
      diagnostic = "Expected stderr to include the line #{line}\n#{stderr}"
      assert stderr.include?(line), diagnostic
    end
    assert_equal expected_status, status
  end

  # - - - - - - - - - - - - - - - - -

  def green_traffic_light_test
    run_cyber_dojo_sh(
      changed_files: {
        'hiker.c' => hiker_c.sub('6 * 9', '6 * 7')
      }
    )
    assert green?, run_result
    assert_equal '', stderr
    assert_equal '0', status
  end

end
