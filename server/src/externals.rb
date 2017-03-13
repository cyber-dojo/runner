#require_relative 'disk_writer'
#require_relative 'bash_sheller'
require_relative 'logger_stdout'

module Externals # mix-in

  #def  shell;  @shell ||=  BashSheller.new(self); end
  #def   disk;   @disk ||=   DiskWriter.new(self); end
  def    log;    @log ||= LoggerStdout.new(self); end

end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# How does Externals work? How are they designed to be used?
#
# 1. include Externals in your top-level scope.
#
#    require_relative 'externals'
#    class MicroService < Sinatra::Base
#      ...
#      private
#      include Externals
#      ...
#    end
#
# 2. All child objects have access to their parent
#    and gain access to the externals via nearest_ancestors()
#
#    require_relative 'nearest_ancestors'
#    class Runner
#      def initialize(parent)
#        @parent = parent
#      end
#      attr_reader :parent
#      ...
#      private
#      include NearestAncestors
#      def log; nearest_ancestors(:log); end
#      ...
#    end
#
# 3. In tests you can simply set the externals @vars directly.
#
#    class ExampleTest < MiniTest::Test
#      def test_something
#        @log = SpyLogger.new(...)
#        runner = DockerRunner.new(self)
#        runner.do_something
#        assert_equal 'expected', @log.spied
#      end
#    end
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - -
