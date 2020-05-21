# frozen_string_literal: true
require_relative 'bash'
require_relative 'log'
require_relative 'string_logger'
require_relative 'traffic_light'
require_relative 'rag_lambdas'

class Externals

  def initialize(options = {})
    #stdout = options.delete(:stdout) || StdoutWriter.new(self)
    @logger = options[:logger] || StringLogger.new(self)
    @bash = options[:bash] || Bash.new(self)
    @rag_lambdas = options[:rag_lambdas] || RagLambdas.new
    @traffic_light = options[:traffic_light] || TrafficLight.new(self)

    @log = options['log'] || Log.new
  end

  attr_reader :bash, :log, :logger
  attr_reader :rag_lambdas, :traffic_light

end
