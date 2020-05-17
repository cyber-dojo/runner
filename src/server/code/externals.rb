# frozen_string_literal: true
require_relative 'bash'
require_relative 'log'
require_relative 'shell'
require_relative 'traffic_light'

class Externals

  def bash
    @bash ||= Bash.new
  end
  def bash=(e)
    @bash = e
  end

  def log
    @log ||= Log.new
  end
  def log=(e)
    @log = e
  end

  def shell
    @shell ||= Shell.new(self)
  end

  def traffic_light
    @traffic_light ||= TrafficLight.new(self)
  end

end
