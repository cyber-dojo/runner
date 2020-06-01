# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'stdout_writer'
require_relative 'string_logger'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize
    @bash = ExternalBash.new(self)
    @logger = StringLogger.new(self)
    @process = ExternalProcess.new(self)
    @rag_lambdas = RagLambdas.new
    @stdout = StdoutWriter.new(self)
    @traffic_light = TrafficLight.new(self)
  end

  attr_reader :bash, :logger, :process, :rag_lambdas, :stdout, :traffic_light

end
