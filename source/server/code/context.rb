# frozen_string_literal: true
require_relative 'external_logger'
require_relative 'external_process'
require_relative 'external_sheller'
require_relative 'external_threader'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context

  def initialize(options = {})
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @logger   = options[:logger]   || ExternalLogger.new
    @process  = options[:process]  || ExternalProcess.new
    @sheller  = options[:sheller]  || ExternalSheller.new(self)
    @threader = options[:threader] || ExternalThreader.new
  end

  attr_reader :prober, :puller, :runner
  attr_reader :logger, :process, :sheller, :threader

end
