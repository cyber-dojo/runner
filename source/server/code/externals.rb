# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'external_threader'
require_relative 'stream_writer'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize(options = {})
    @logger = options[:logger] || StreamWriter.new($stdout)

    @bash = options[:bash] || ExternalBash.new
    @process = options[:process] || ExternalProcess.new
    @threader = options[:threader] || ExternalThreader.new

    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @traffic_light = options[:traffic_light] || TrafficLight.new(self)
  end

  attr_reader :logger
  attr_reader :bash, :process, :threader
  attr_reader :rag_lambdas, :traffic_light

end
