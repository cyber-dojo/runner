# frozen_string_literal: true
require_relative 'bash'
require_relative 'external_process'
require_relative 'traffic_light'

class Externals

  def initialize
    @bash = Bash.new
    @process = ExternalProcess.new
    @traffic_light = TrafficLight.new(self) # singleton cache
  end

  attr_reader :bash, :process, :traffic_light

end
