# frozen_string_literal: true
require_relative 'test_base'

class FeatureBaselineSpeedTest < TestBase

  def self.id58_prefix
    '159'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A6',
  'baseline average speed is less than 1.5 secs' do
    timings = []
    (1..5).each do
      started_at = Time.now
      assert_cyber_dojo_sh('true')
      stopped_at = Time.now
      diff = Time.at(stopped_at - started_at).utc
      secs = diff.strftime("%S").to_i
      millisecs = diff.strftime("%L").to_i
      timings << (secs * 1000 + millisecs)
    end
    mean = timings.reduce(0, :+) / timings.size
    assert mean < max=1500, "mean=#{mean}, max=#{max}"
  end

end
