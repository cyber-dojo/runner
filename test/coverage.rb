require 'simplecov'

SimpleCov.start do
  filters.clear
  coverage_dir(ENV['COVERAGE_ROOT'])
  #add_group('debug') { |src| puts src.filename; false }
  add_group('app') { |src| src.filename =~ %r"^/app/" }
  add_group('test') { |src| src.filename =~ %r"^/test/.*_test\.rb$" }
end
