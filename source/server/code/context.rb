# frozen_string_literal: true
require_relative 'external_process'
require_relative 'external_sheller'
require_relative 'external_threader'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'
require_relative 'stream_writer'

class Context

  def initialize(options = {})
    @logger = options[:logger] || StreamWriter.new($stdout)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @process  = options[:process]  || ExternalProcess.new
    @sheller  = options[:sheller]  || ExternalSheller.new(self)
    @threader = options[:threader] || ExternalThreader.new
  end

  attr_reader :logger, :prober, :puller, :runner
  attr_reader :process, :sheller, :threader

end
