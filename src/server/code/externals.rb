# frozen_string_literal: true
require_relative 'bash'
require_relative 'traffic_light'

class Externals

  def bash
    @bash ||= Bash.new
  end
  def bash=(o)
    @bash = o
  end

  def traffic_light
    @traffic_light ||= TrafficLight.new(self)
  end

end
