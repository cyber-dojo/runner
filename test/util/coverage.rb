require 'simplecov'

cov_root = File.expand_path('../..', File.dirname(__FILE__))

SimpleCov.start do
  #add_group('debug') { |code| print(code.filename+"\n"); false }
  add_group('src') { |src|
    src.filename.start_with?("#{cov_root}/src")
  }
  add_group('test') { |test|
    test.filename.start_with?("#{cov_root}/test")
  }
end

SimpleCov.root(cov_root)
SimpleCov.coverage_dir(ENV['COVERAGE_ROOT'])
