# frozen_string_literal: true
require 'simplecov'
require_relative 'simplecov_json'

CONTEXT = ENV.fetch('CONTEXT', nil)

def runner_nocov_token
  ['nocov', CONTEXT].join('_')
end

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir("#{ENV.fetch('COVERAGE_ROOT', nil)}")
  nocov_token(runner_nocov_token)

  code_tab = ENV.fetch('COVERAGE_CODE_TAB_NAME', nil)
  test_tab = ENV.fetch('COVERAGE_TEST_TAB_NAME', nil)

  #add_group('debug') { |src| puts src.filename; false }

  add_group(test_tab) { |src|
    src.filename.start_with?("/runner/test/#{CONTEXT}/") ||
    src.filename.start_with?("/runner/test/dual/")
  }
  add_group(code_tab) { |src|
    !src.filename.start_with?("/runner/test/")
  }
end

formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(formatters)
