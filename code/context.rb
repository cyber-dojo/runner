# frozen_string_literal: true
require_relative 'externals/bash_sheller'
require_relative 'externals/piper'
require_relative 'externals/process_spawner'
require_relative 'externals/random'
require_relative 'externals/stdout_logger'
require_relative 'externals/asynchronous_threader'
require_relative 'node'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context

  def initialize(options = {})
    @node   = options[:node  ] || Node.new(self)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @process  = options[:process ] || ProcessSpawner.new
    @sheller  = options[:sheller ] || BashSheller.new(self)
    @threader = options[:threader] || AsynchronousThreader.new
    @piper    = options[:piper   ] || Piper.new

    @logger = options[:logger] || StdoutLogger.new
    @random = options[:random] || Random.new
  end

  attr_reader :node, :prober, :puller, :runner
  attr_reader :process, :sheller, :threader, :piper
  attr_reader :logger, :random

end
