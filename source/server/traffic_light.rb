# frozen_string_literal: true
require_relative 'empty_binding'
require_relative 'rag_lambdas'
require 'json'

class TrafficLight
  class Fault < RuntimeError
    def initialize(properties)
      super
      @properties = properties
    end
    attr_reader :properties
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def initialize(context)
    @context = context
    @rag_lambdas = RagLambdas.new
  end

  def colour(image_name, stdout, stderr, status)
    [self[image_name].call(stdout, stderr, status), {}]
  rescue Fault => e
    fault_info = {
      call: 'TrafficLight.colour(image_name,stdout,stderr,status)',
      args: {
        image_name: image_name,
        stdout: stdout.lines,
        stderr: stderr.lines,
        status: status
      },
      exception: e.properties
    }
    logger.log(JSON.pretty_generate(fault_info))
    ['faulty', fault_info]
  end

  private

  def [](image_name)
    light = @rag_lambdas[image_name]
    return light unless light.nil?

    lambda_source = checked_read_lambda_source(image_name)
    fn = checked_eval(lambda_source)
    @rag_lambdas.compute(image_name) do
      lambda { |stdout, stderr, status|
        colour = checked_call(fn, lambda_source, stdout, stderr, status)
        checked_colour(colour, lambda_source)
      }
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_read_lambda_source(image_name)
    command = [
      'docker run --rm --entrypoint=cat',
      image_name,
      RAG_LAMBDA_FILENAME
    ].join(SPACE)
    stdout, stderr, status = sheller.capture(command)
    if status.zero?
      message = "Read red-amber-green lambda for #{image_name}"
      logger.log(message)
      stdout
    else
      raise Fault.new({
                        context: "image_name must have #{RAG_LAMBDA_FILENAME} file",
                        command: command,
                        stdout: stdout.lines,
                        stderr: stderr.lines,
                        status: status
                      })
    end
  end

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

  SPACE = ' '

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_eval(lambda_source)
    Empty.binding.eval(lambda_source)
  rescue Exception => e
    raise Fault.new({
                      context: "exception when eval'ing lambda source",
                      lambda_source: lambda_source.lines,
                      class: e.class.name,
                      message: e.message.lines
                    })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_call(func, lambda_source, stdout, stderr, status)
    func.call(stdout, stderr, status.to_i).to_s
  rescue Exception => e
    raise Fault.new({
                      context: 'exception when calling lambda source',
                      lambda_source: lambda_source.lines,
                      class: e.class.name,
                      message: e.message.lines
                    })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def checked_colour(colour, lambda_source)
    if LEGAL_COLOURS.include?(colour)
      colour
    else
      raise Fault.new({
                        context: "illegal colour; must be one of ['red','amber','green']",
                        illegal_colour: colour,
                        lambda_source: lambda_source.lines
                      })
    end
  end

  LEGAL_COLOURS = %w[red amber green].freeze

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def logger
    @context.logger
  end

  def sheller
    @context.sheller
  end
end
