require 'simplecov'

cov_root = File.expand_path('..', File.dirname(__FILE__))

SimpleCov.start do

  #add_group('debug') { |src| print src.filename+"\n"; false }

  add_filter 'src/micro_service.rb' # done from client container
  add_filter 'test/src/kata_container_test.rb' # runner specific

  add_group 'src',      "#{cov_root}/src"
  add_group 'test/src', "#{cov_root}/test/src"
end

SimpleCov.root cov_root
SimpleCov.coverage_dir ENV['CYBER_DOJO_COVERAGE_ROOT']