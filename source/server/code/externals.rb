# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'stream_writer'
require_relative 'string_logger'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize(options)
    @bash = options[:bash] || ExternalBash.new
    @logger = options[:logger] || StringLogger.new
    @process = options[:process] || ExternalProcess.new
    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @stdout = options[:stdout] || StreamWriter.new($stdout)
    @stderr = options[:stderr] || StreamWriter.new($stderr)
    @traffic_light = options[:traffic_lights] || TrafficLight.new(self)
  end

  attr_reader :bash, :logger, :process, :rag_lambdas, :stdout, :stderr, :traffic_light

end
