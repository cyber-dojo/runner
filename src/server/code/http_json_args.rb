# frozen_string_literal: true
require 'json'
require_relative 'prober'
require_relative 'runner'

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
    when '/sha'                then [Prober,{},'sha']
    when '/alive'              then [Prober,{},'alive?']
    when '/ready'              then [Prober,{},'ready?']
    when '/run_cyber_dojo_sh'  then [Runner,run_args,'run_cyber_dojo_sh']
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
    if arg_exists?('manifest')
      new_run_args
    else
      existing_run_args
    end
  end

  def new_run_args
    { 'id' => id,
      'files' => files,
      'manifest' => manifest
    }
  end

  def existing_run_args
    { 'id' => id,
      'files' => files,
      'manifest' => {
        'image_name' => image_name,
        'max_seconds' => max_seconds
      }
    }
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

  def manifest
    exists_arg('manifest')
  end

  def image_name
    exists_arg('image_name')
  end

  def max_seconds
    exists_arg('max_seconds')
  end

  # - - - - - - - - - - - - - - - -

  def exists_arg(name)
    unless arg_exists?(name)
      raise missing(name)
    end
    arg = @args[name]
    arg
  end

  def arg_exists?(name)
    @args.has_key?(name)
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
