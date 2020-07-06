# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'external_threader'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'
require_relative 'stream_writer'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Context

  def initialize(options = {})
    @logger = options[:logger] || StreamWriter.new($stdout)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    @bash = options[:bash] || ExternalBash.new(self)
    @process = options[:process] || ExternalProcess.new
    @threader = options[:threader] || ExternalThreader.new

    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @traffic_light = options[:traffic_light] || TrafficLight.new(self)
  end

  attr_reader :logger, :prober, :puller, :runner

  attr_reader :bash, :process, :threader
  attr_reader :rag_lambdas, :traffic_light

end
