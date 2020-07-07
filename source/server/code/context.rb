# frozen_string_literal: true
require_relative 'externals/stdout_logger'
require_relative 'externals/process_adapter'
require_relative 'externals/bash_sheller'
require_relative 'externals/asynchronous_threader'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context

  def initialize(options = {})
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @logger   = options[:logger]   || StdoutLogger.new
    @process  = options[:process]  || ProcessAdapter.new
    @sheller  = options[:sheller]  || BashSheller.new(self)
    @threader = options[:threader] || AsynchronousThreader.new
  end

  attr_reader :prober, :puller, :runner
  attr_reader :logger, :process, :sheller, :threader

end
