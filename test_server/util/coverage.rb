require 'simplecov'

def app_root
  File.expand_path('../..', __dir__)
end

def app_file?(filename)
  filename.start_with?("#{app_root}/src" )
  #filename.start_with?("#{app_root}/" ) &&
  #  !filename.start_with?("#{app_root}/test/")
end

def test_file?(filename)
  filename.start_with?("#{app_root}/test/") &&
    filename.end_with?('_test.rb')
end

SimpleCov.start do
  #add_group('debug') {|src| puts src.filename; false; }
  add_group('app') { |src| app_file?(src.filename) }
  add_group('test') { |src| test_file?(src.filename) }
end
SimpleCov.root(app_root)
SimpleCov.coverage_dir(ENV['COVERAGE_ROOT'])
