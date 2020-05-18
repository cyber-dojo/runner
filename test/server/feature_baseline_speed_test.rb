# frozen_string_literal: true
require_relative 'test_base'
require 'benchmark'

class BaselineSpeedTest < TestBase

  def self.id58_prefix
    '159'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A6',
  'baseline average speed is less than 1 secs' do
    n = 5
    t = Benchmark.realtime {
      n.times {
        assert_cyber_dojo_sh('true')
      }
    }
    average = t /  n
    assert average < max=1000, "average=#{average}, max=#{max}"
  end

end
