# frozen_string_literal: true
require 'json'
require 'minitest/reporters'

class Minitest::Reporters::SlimJsonReporter < Minitest::Reporters::BaseReporter
  def report
    super
    filename = "#{ENV.fetch('COVERAGE_ROOT')}/test_metrics.json"
    metrics = {
      total_time: format('%.2f', total_time),
      assertion_count: assertions,
      test_count: count,
      failure_count: failures,
      error_count: errors,
      skip_count: skips
    }
    File.write(filename, JSON.pretty_generate(metrics))
  end
end
