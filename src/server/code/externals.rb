# frozen_string_literal: true
require_relative 'bash'
require_relative 'string_logger'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize(options = {})
    #stdout = options[:stdout] || StdoutWriter.new(self)
    @bash = options[:bash] || Bash.new(self)
    @logger = options[:logger] || StringLogger.new(self)
    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @traffic_light = options[:traffic_light] || TrafficLight.new(self)
  end

  attr_reader :bash, :logger, :rag_lambdas, :traffic_light

end
