# frozen_string_literal: true
require 'simplecov'
require_relative 'simplecov_formatter_json'

CONTEXT = ENV.fetch('CONTEXT', nil)
ROOT_DIR = '/runner'

def runner_nocov_token
  ['nocov', CONTEXT].join('_')
end

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir(ENV.fetch('COVERAGE_ROOT', nil).to_s)
  nocov_token(runner_nocov_token)
  root(ROOT_DIR)

  code_tab = ENV.fetch('COVERAGE_CODE_TAB_NAME', nil)
  test_tab = ENV.fetch('COVERAGE_TEST_TAB_NAME', nil)

  # add_group('debug') { |src| puts src.filename; false }

  add_group(test_tab) do |src|
    src.filename.start_with?("#{ROOT_DIR}/test/#{CONTEXT}/") || src.filename.start_with?("#{ROOT_DIR}/test/dual/")
  end
  add_group(code_tab) do |src|
    src.filename.start_with?("#{ROOT_DIR}/source/")
  end
end

formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(formatters)
