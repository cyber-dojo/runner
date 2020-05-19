# frozen_string_literal: true
require_relative 'bash'
require_relative 'traffic_light'

class Externals

  def initialize
    @bash = Bash.new
    @traffic_light = TrafficLight.new(self)
  end

  attr_reader :bash, :traffic_light

end
