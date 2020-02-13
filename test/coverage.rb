require 'simplecov'

SimpleCov.start do
  #enable_coverage :branch
  filters.clear
  coverage_dir(ENV['COVERAGE_ROOT'])
  #add_group('debug') { |src| puts src.filename; false }
  add_group(ENV['COVERAGE_CODE_GROUP_NAME']) { |src|
    src.filename =~ %r"^/app/"
  }
  add_group(ENV['COVERAGE_TEST_GROUP_NAME']) { |src|
    src.filename =~ %r"^/test/.*_test\.rb$"
  }
end
