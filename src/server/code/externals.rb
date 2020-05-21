# frozen_string_literal: true
require_relative 'bash'
require_relative 'log'
require_relative 'shell'
require_relative 'traffic_light'

class Externals

  def initialize(options = {})
    @bash = options['bash'] || Bash.new
    @log = options['log'] || Log.new
    @shell = Shell.new(self)
    @traffic_light = TrafficLight.new(self)
  end

  attr_reader :bash, :log, :shell, :traffic_light

end
