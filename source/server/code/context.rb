# frozen_string_literal: true
require_relative 'externals/stdout_logger'
require_relative 'externals/process_spawner'
require_relative 'externals/bash_sheller'
require_relative 'externals/threader_asynchronous'
require_relative 'node'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context

  def initialize(options = {})
    @node   = options[:node]   || Node.new(self)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @logger   = options[:logger]   || StdoutLogger.new
    @process  = options[:process]  || ProcessSpawner.new
    @sheller  = options[:sheller]  || BashSheller.new(self)
    @threader = options[:threader] || ThreaderAsynchronous.new
  end

  attr_reader :node, :prober, :puller, :runner
  attr_reader :logger, :process, :sheller, :threader

end
