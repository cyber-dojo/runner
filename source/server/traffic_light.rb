require_relative 'empty_binding'
require_relative 'rag_lambdas'
require_relative 'tarfile_reader'
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

  def colour_from_image(image_name, stdout, stderr, status)
    [self[image_name].call(stdout, stderr, status), {}]
  rescue Fault => e
    fault_info = {
      call: 'TrafficLight.colour_from_image(image_name,stdout,stderr,status)',
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

  def colour_from_lambda(lambda_source, stdout, stderr, status)
    fn = checked_eval(lambda_source)
    colour = checked_call(fn, lambda_source, stdout, stderr, status)
    checked_colour(colour, lambda_source)
  rescue Fault => e
    fault_info = {
      call: 'TrafficLight.colour_from_lambda(lambda_source,stdout,stderr,status)',
      args: {
        lambda_source: lambda_source,
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

  # Reads one file out of the image. The container is created and never
  # started, which is enough for the daemon to copy a file out of it, and is
  # why none of DaemonRun's machinery appears here. Nothing removes a
  # container that never ran, so the DELETE is not optional.
  # See docs/profiling/check_archive_from_unstarted_container.rb
  def checked_read_lambda_source(image_name)
    id = created_container_id(image_name)
    begin
      code, body = daemon.request('GET', "/containers/#{id}/archive?path=#{RAG_LAMBDA_FILENAME}")
    ensure
      daemon.request('DELETE', "/containers/#{id}")
    end
    unless code == 200
      raise Fault.new({
                        context: "image_name must have #{RAG_LAMBDA_FILENAME} file",
                        image_name: image_name,
                        code: code,
                        body: body
                      })
    end

    logger.log("Read red-amber-green lambda from #{image_name}")
    TarFile::Reader.new(body).files.values.first
  end

  # Image is all the create needs, since nothing in the container executes.
  def created_container_id(image_name)
    _code, body = daemon.request('POST', '/containers/create', { 'Image' => image_name })
    JSON.parse(body)['Id']
  end

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'.freeze

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

  def daemon
    @context.daemon
  end
end
