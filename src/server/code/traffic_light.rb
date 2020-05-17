# frozen_string_literal: true
require_relative 'empty'
require 'concurrent'

class TrafficLight

  def initialize(externals)
    @externals = externals
    @map = Concurrent::Map.new
  end

  def colour(image_name, stdout, stderr, status)
    self[image_name].call(stdout, stderr, status)
  end

  private

  def [](image_name)
    light = @map[image_name]
    return light unless light.nil?

    #shell.assert("docker pull #{image_name}")

    docker_run_command = [
      'docker run --rm --entrypoint=cat',
      image_name,
      RAG_LAMBDA_FILENAME
    ].join(' ')
    lambda_src,_stderr,status = shell.exec(docker_run_command)
    if status != 0
      return faulty(image_name)
    end

    begin
      bulb = Empty.binding.eval(lambda_src)
    rescue Exception
      return faulty(image_name)
    end

    @map.compute(image_name) { wrapped(image_name, bulb) }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'
  COLOURS =

  def wrapped(image_name, bulb)
    #puts "Populating traffic_light @map for #{image_name}"
    lambda { |stdout,stderr,status|
      begin
        colour = bulb.call(stdout,stderr,status)
        if is_working?(colour)
          colour.to_s
        else
          :faulty.to_s
        end
      rescue Exception
        :faulty.to_s
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def faulty(image_name)
    lambda { |_stdout, _stderr, _status|
      'faulty'
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def is_working?(colour)
    [ :red, :amber, :green ].include?(colour)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def shell
    @externals.shell
  end

end
