# frozen_string_literal: true
require_relative 'empty'
require 'concurrent'
require 'json'

class TrafficLight

  class Fault < RuntimeError
    def initialize(info)
      super(JSON.pretty_generate(info))
    end
  end

  def initialize(externals)
    @externals = externals
    @map = Concurrent::Map.new
  end

  def colour(image_name, stdout, stderr, status)
    self[image_name].call(stdout, stderr, status)
  rescue Exception => error
    logger.write("Faulty TrafficLight.colour(image_name,stdout,stderr,status):")
    logger.write("image_name:#{image_name}:")
    logger.write("stdout:#{stdout}:")
    logger.write("stderr:#{stderr}:")
    logger.write("status:#{status}:")
    logger.write("exception:#{error.class.name}:")
    logger.write("message:#{error.message}:")
    'faulty'
  end

  private

  def [](image_name)
    light = @map[image_name]
    return light unless light.nil?
    #bash.exec("docker pull #{image_name}")
    lambda_source = checked_read_lambda_source(image_name)
    fn = checked_eval(lambda_source)
    @map.compute(image_name) {
      lambda { |stdout,stderr,status|
        colour = checked_call(fn, lambda_source, stdout, stderr, status)
        checked_colour(colour, lambda_source)
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_read_lambda_source(image_name)
    command = [ 'docker run --rm --entrypoint=cat', image_name, RAG_LAMBDA_FILENAME ].join(' ')
    stdout,stderr,status = bash.exec(command)
    if status === 0
      stdout
    else
      fail TrafficLight::Fault, {
        context: "image_name must have #{RAG_LAMBDA_FILENAME} file",
        command: command,
        stdout: stdout,
        stderr: stderr,
        status: status
      }
    end
  end

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_eval(lambda_source)
    Empty.binding.eval(lambda_source)
  rescue Exception => error
    fail TrafficLight::Fault, {
      context: "exception when eval'ing lambda source",
      lambda_source: lambda_source,
      class: error.class.name,
      message: error.message
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_call(fn, lambda_source, stdout, stderr, status)
    fn.call(stdout,stderr,status.to_i).to_s
  rescue Exception => error
    fail TrafficLight::Fault, {
      context: "exception when calling lambda source",
      lambda_source: lambda_source,
      class: error.class.name,
      message: error.message
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_colour(colour, lambda_source)
    if LEGAL_COLOURS.include?(colour)
      colour
    else
      fail TrafficLight::Fault, {
        context: "illegal colour; must be one of ['red','amber','green']",
        illegal_colour: colour,
        lambda_source: lambda_source
      }
    end
  end

  LEGAL_COLOURS = [ 'red', 'amber', 'green' ]

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def bash
    @externals.bash
  end

  def logger
    @externals.logger
  end

end
