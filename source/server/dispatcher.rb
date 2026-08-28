require 'json'
require_relative 'docker_image_name'

class Dispatcher
  class RequestError < RuntimeError
  end

  def initialize(context)
    @context = context
  end

  def call(path, body)
    args = parse_json_args(body)
    case path
    when '/alive'              then ['alive?',            prober.alive?(**args)]
    when '/ready'              then ['ready?',            prober.ready?(**args)]
    when '/sha'                then ['sha',               prober.sha(**args)]
    when '/pull_image'         then ['pull_image',        pull_and_warm(**args)]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh', runner.run_cyber_dojo_sh(**args)]
    else
      raise request_error('unknown path')
    end
  rescue JSON::JSONError
    raise request_error('body is not JSON')
  rescue DockerImageName::Malformed
    raise request_error('malformed image_name')
  rescue DockerImageName::Unversioned
    raise request_error('unversioned image_name')
  rescue Exception => e
    if (r = e.message.match('(missing|unknown) keyword(s?): (.*)'))
      raise request_error("#{r[1]} argument#{r[2]}: #{r[3]}")
    end

    raise
  end

  private

  def parse_json_args(body)
    if body == ''
      {}
    else
      json = JSON.parse!(body)
      raise request_error('body is not JSON Hash') unless json.is_a?(Hash)

      # double-splats in call() requires top-level symbol keys
      json.transform_keys(&:to_sym)
    end
  end

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    Dispatcher::RequestError.new(text)
  end

  # Creator calls this when a kata is created, which is the earliest the runner
  # learns an image is about to be wanted, so it is the earliest a spare can be
  # waiting for the kata's first test-run.
  #
  # Only when the image is already on the node. :pulling means it is not there
  # yet, so there is nothing to make a container from; that image gets its
  # spare from the refill after its first test-run instead. Warming anyway
  # would ask the daemon for a container it cannot make and log a failure that
  # says nothing is wrong.
  def pull_and_warm(id:, image_name:)
    answer = images.pull(id: id, image_name: image_name)
    spares.warm(image_name: image_name) if answer == :pulled
    answer
  end

  def prober
    @context.prober
  end

  def images
    @context.images
  end

  def runner
    @context.runner
  end

  def spares
    @context.spares
  end
end
