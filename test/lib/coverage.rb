# frozen_string_literal: true
require 'simplecov'
require_relative 'simplecov-json'

def runner_nocov_token
  ['nocov', ENV.fetch('CONTEXT', nil)].join('_')
end

SimpleCov.start do
  enable_coverage :branch
  filters.clear
  coverage_dir("#{ENV.fetch('REPORTS_ROOT', nil)}/coverage")
  nocov_token(runner_nocov_token)
  # add_group('debug') { |src| puts src.filename; false }
  code_dir = ENV.fetch('CODE_DIR', nil)
  test_dir = ENV.fetch('TEST_DIR', nil)
  add_group(code_dir) { |src| src.filename =~ %r{^/runner/#{code_dir}/} }
  add_group(test_dir) { |src| src.filename =~ %r{^/runner/#{test_dir}/.*_test\.rb$} }
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
                                                                  SimpleCov::Formatter::HTMLFormatter,
                                                                  SimpleCov::Formatter::JSONFormatter
                                                                ])
