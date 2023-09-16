require 'simplecov'
require_relative 'simplecov-json'

def runner_nocov_token
  [ 'nocov', ENV['CONTEXT'] ].join('_')
end

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir(ENV['COVERAGE_ROOT'])
  nocov_token(runner_nocov_token)
  # add_group('debug') { |src| puts src.filename; false }
  code_dir = ENV['CODE_DIR']
  test_dir = ENV['TEST_DIR']
  add_group(code_dir) { |src| src.filename =~ %r"^/runner/#{code_dir}/" }
  add_group(test_dir) { |src| src.filename =~ %r"^/runner/#{test_dir}/.*_test\.rb$" }
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter,
])
