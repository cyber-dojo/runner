# frozen_string_literal: true
require_relative 'external_bash'
require_relative 'external_process'
require_relative 'traffic_light'

class Externals

  def initialize
    @bash = ExternalBash.new
    @process = ExternalProcess.new
    @traffic_light = TrafficLight.new(self) # caches lambdas
  end

  attr_reader :bash, :process, :traffic_light

end
