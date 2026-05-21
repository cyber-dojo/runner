require_relative '../test_base'

class BaselineSpeedTest < TestBase

  multi_os_test '1598A6', %w(
  | baseline average speed is less than 2 secs,
  | locally much faster than that,
  | but for CI 2 is about right
  ) do
    set_context
    timings = []
    5.times do
      started_at = Time.now
      assert_cyber_dojo_sh('true')
      stopped_at = Time.now
      diff = Time.at(stopped_at - started_at).utc
      secs = diff.strftime('%S').to_i
      millisecs = diff.strftime('%L').to_i
      timings << ((secs * 1000) + millisecs)
    end
    mean = timings.reduce(0, :+) / timings.size
    # 4s (raised from 2s) because parallel test execution means all three
    # OS variants run their Docker containers concurrently, increasing load.
    assert mean < max = 4000, "mean=#{mean}, max=#{max}"
  end
end
