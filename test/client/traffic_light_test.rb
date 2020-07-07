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

  test '3DE', 'when there is a fault, log contains fault_info as JSON string' do
    run_cyber_dojo_sh(image_name:'busybox:latest')
    assert_equal 'faulty', @result['colour']
    fault_info = JSON.parse(@result['log'])
    assert_equal 'TrafficLight.colour(image_name,stdout,stderr,status)', fault_info['call']
    assert_equal 'busybox:latest', fault_info['args']['image_name']
    assert_equal 'TrafficLight::Fault', fault_info['exception']
    assert_equal 'image_name must have /usr/local/bin/red_amber_green.rb file', fault_info['message']['context']
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
    assert_equal 'red', colour
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
    assert_equal 'amber', colour
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
    assert_equal 'green', colour, result
    assert_equal '', stderr
    assert_equal '0', status
  end

end
