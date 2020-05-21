# frozen_string_literal: true
require_relative 'bash'
require_relative 'log'
require_relative 'shell'
require_relative 'string_logger'
require_relative 'traffic_light'

class Externals

  def initialize(options = {})
    #stdout = options.delete(:stdout) || StdoutWriter.new
    @logger = options.delete(:logger) || StringLogger.new
    @bash = options.delete(:bash) || Bash.new(@logger)
    @traffic_light = TrafficLight.new(self)

    @log = options['log'] || Log.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :log, :logger, :shell, :traffic_light

end
