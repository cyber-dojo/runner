# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'external_threader'
require_relative 'stream_writer'
require_relative 'string_logger'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize(options)
    @bash = options[:bash] || ExternalBash.new
    @process = options[:process] || ExternalProcess.new
    @threader = options[:threder] || ExternalThreader.new

    @logger = options[:logger] || StringLogger.new
    @stdout = options[:stdout] || StreamWriter.new($stdout)
    @stderr = options[:stderr] || StreamWriter.new($stderr)

    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @traffic_light = options[:traffic_lights] || TrafficLight.new(self)
  end

  attr_reader :bash, :process, :threader
  attr_reader :logger, :stdout, :stderr
  attr_reader :rag_lambdas, :traffic_light

end
