require_relative 'lib/empty_binding'
require_relative 'lib/tarfile_reader'
require 'concurrent'
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
    # Keyed by the source rather than by whoever supplied it, so a rag-lambda
    # written once in a start-point is compiled once however many images and
    # katas answer with it.
    @lambdas = Concurrent::Map.new # lambda_source => fn
    @sources = Concurrent::Map.new # image_name => lambda_source
  end

  def colour_from_image(image_name, stdout, stderr, status)
    [colour_of(source_from_image(image_name), stdout, stderr, status), {}]
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
    [colour_of(lambda_source, stdout, stderr, status), {}]
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

  # What both entry points do once they have the source, whether it came from
  # a manifest or out of an image.
  def colour_of(lambda_source, stdout, stderr, status)
    fn = fn_of(lambda_source)
    colour = checked_call(fn, lambda_source, stdout, stderr, status)
    checked_colour(colour, lambda_source)
  end

  # The eval happens outside the store, so a source that will not compile
  # raises on every call and nothing is remembered for it. Two callers racing
  # on the same new source both compile it and the second one's fn wins, which
  # costs a duplicate eval and answers the same lambda either way.
  def fn_of(lambda_source)
    fn = @lambdas[lambda_source]
    return fn unless fn.nil?

    fn = checked_eval(lambda_source)
    @lambdas.compute(lambda_source) { fn }
  end

  # Reading a source out of an image costs a container created and removed, so
  # it happens once per image. Nothing invalidates it: an image re-pushed
  # under the same tag keeps its old lambda until the process restarts.
  def source_from_image(image_name)
    lambda_source = @sources[image_name]
    return lambda_source unless lambda_source.nil?

    lambda_source = checked_read_lambda_source(image_name)
    @sources.compute(image_name) { lambda_source }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # Reads one file out of the image. The container is created and never
  # started, which is enough for the daemon to copy a file out of it, and is
  # why none of CyberDojoShRunner's machinery appears here. Nothing removes a
  # container that never ran, so the DELETE is not optional.
  # See docs/profiling/check_archive_from_unstarted_container.rb
  def checked_read_lambda_source(image_name)
    id = created_container_id(image_name)
    begin
      code, body = docker.read_file(id, RAG_LAMBDA_FILENAME)
    ensure
      docker.remove_container(id)
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
    _code, body = docker.create_container({ 'Image' => image_name })
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
    if %w[red amber green].include?(colour)
      colour
    else
      raise Fault.new({
                        context: "illegal colour; must be one of ['red','amber','green']",
                        illegal_colour: colour,
                        lambda_source: lambda_source.lines
                      })
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def logger
    @context.logger
  end

  def docker
    @context.docker
  end
end
