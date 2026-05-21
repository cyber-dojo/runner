require 'minitest/reporters'

module SlowTestsTimings
  TIMINGS = {}
  LOCK = Mutex.new
end

class Minitest::Reporters::SlowTestsReporter < Minitest::Reporters::BaseReporter
  def report
    super
    sorted = SlowTestsTimings::TIMINGS
               .select { |_name, secs| secs > 0.000 }
               .sort_by { |_name, secs| -secs }
               .first(5)
    puts
    puts 'Slowest tests are...'
    sorted.each do |(name, secs)|
      puts format('%3.4f - %-72s', secs, name)
    end
    puts
  end
end
