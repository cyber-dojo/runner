# frozen_string_literal: true
require_relative 'empty'
require 'concurrent'

class TrafficLightColour

  def initialize(externals)
    @externals = externals
    @map = Concurrent::Map.new
  end

  def [](image_name)
    light = @map[image_name]
    return light unless light.nil?

    #shell.assert("docker pull #{image_name}")
    lambda_src = shell.assert("docker run --rm --entrypoint=cat #{image_name} #{RAG_LAMBDA_FILENAME}")
    bulb = Empty.binding.eval(lambda_src)

    @map.compute(image_name) { wrapped(image_name, bulb) }
  end

  private

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'
  COLOURS = [ :red, :amber, :green ]

  def wrapped(image_name, bulb)
    lambda { |stdout,stderr,status|
      begin
        colour = bulb.call(stdout,stderr,status)
        if COLOURS.include?(colour)
          colour.to_s
        else
          :faulty.to_s
        end
      rescue Exception
        :faulty.to_s
      end
    }
  end

  def shell
    @externals.shell
  end

end
