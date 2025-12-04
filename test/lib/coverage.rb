# frozen_string_literal: true
require 'simplecov'
require_relative 'simplecov_formatter_json'

CONTEXT = ENV.fetch('CONTEXT')
APP_DIR = ENV.fetch('APP_DIR')

def runner_nocov_token
  ['nocov', CONTEXT].join('_')
end

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir(ENV.fetch('COVERAGE_ROOT', nil).to_s)
  nocov_token(runner_nocov_token)
  root(APP_DIR)

  code_tab = ENV.fetch('COVERAGE_CODE_TAB_NAME')
  test_tab = ENV.fetch('COVERAGE_TEST_TAB_NAME')

  # add_group('debug') { |the| puts the.filename; false }

  add_group(test_tab) do |the|
    the.filename.start_with?("#{APP_DIR}/test/#{CONTEXT}/") || the.filename.start_with?("#{APP_DIR}/test/dual/")
  end
  add_group(code_tab) do |the|
    the.filename.start_with?("#{APP_DIR}/source/")
  end
end

formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(formatters)
