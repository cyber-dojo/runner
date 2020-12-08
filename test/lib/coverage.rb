require 'simplecov'
require_relative 'simplecov-json'

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir(ENV['COVERAGE_ROOT'])
  #add_group('debug') { |src| puts src.filename; false }
  code_tab = ENV['COVERAGE_CODE_TAB_NAME']
  test_tab = ENV['COVERAGE_TEST_TAB_NAME']
  add_group(code_tab) { |src| src.filename =~ %r"^/runner/code/" }
  add_group(test_tab) { |src| src.filename =~ %r"^/runner/test/.*_test\.rb$" }
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter,
])
