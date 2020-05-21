# frozen_string_literal: true
require_relative 'test_base'

class LogEmptyTest < TestBase

  def self.id58_prefix
    '6f2'
  end

  # - - - - - - - - - - - - - - - - -

  test 'dFA', %w(
  log_empty? helper method ignores known circleci warning
  ) do
    run_cyber_dojo_sh
    assert_equal 'red', colour, pretty_result(:red)
    unless log.empty?
      log += KNOWN_CIRCLE_CI_WARNING
    end
    original_ENV_CIRCLECI = ENV['CIRCLECI']
    ENV['CIRCLECI'] = 'true'
    assert log_empty?, pretty_result(:circleci_warning_is_ignored_when_on_ci)
  ensure
    ENV['CIRCLECI'] = original_ENV_CIRCLECI
  end

end
