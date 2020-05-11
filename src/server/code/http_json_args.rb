# frozen_string_literal: true
require 'json'

class HttpJsonArgs

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  # - - - - - - - - - - - - - - - -

  def initialize(body)
    @args = json_parse(body)
    unless @args.is_a?(Hash)
      raise request_error('body is not JSON Hash')
    end
  rescue JSON::ParserError
    raise request_error('body is not JSON')
  end

  # - - - - - - - - - - - - - - - -

  def get(path)
    case path
    when '/sha'                then ['sha',{}]
    when '/alive'              then ['alive?',{}]
    when '/ready'              then ['ready?',{}]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh',run_args]
    else
      raise request_error('unknown path')
    end
  end

  private

  def json_parse(body)
    if body === ''
      {}
    else
      JSON.parse(body)
    end
  end

  # - - - - - - - - - - - - - - - -

  def run_args
    { 'image_name' => image_name,
      'id' => id,
      'files' => files,
      'max_seconds' => max_seconds
    }
  end

  # - - - - - - - - - - - - - - - -

  def image_name
    exists_arg('image_name')
  end

  # - - - - - - - - - - - - - - - -

  def id
    exists_arg('id')
  end

  # - - - - - - - - - - - - - - - -

  def files
    exists_arg('files')
  end

  # - - - - - - - - - - - - - - - -

  def max_seconds
    exists_arg('max_seconds')
  end

  # - - - - - - - - - - - - - - - -

  def exists_arg(name)
    unless @args.has_key?(name)
      raise missing(name)
    end
    arg = @args[name]
    arg
  end

  # - - - - - - - - - - - - - - - -

  def missing(arg_name)
    request_error("#{arg_name} is missing")
  end

  # - - - - - - - - - - - - - - - - -

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    HttpJsonArgs::Error.new(text)
  end

end
