# frozen_string_literal: true
require 'json'
require_relative 'prober'
require_relative 'runner'

class Dispatcher

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
    when '/sha'                then [Prober,'sha',{}]
    when '/alive'              then [Prober,'alive?',{}]
    when '/ready'              then [Prober,'ready?',{}]
    when '/run_cyber_dojo_sh'  then [Runner,'run_cyber_dojo_sh',args]
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

  def args
    { 'id' => arg('id'),
      'files' => arg('files'),
      'manifest' => arg('manifest')
    }
  end

  def arg(name)
    unless @args.has_key?(name)
      raise request_error("#{name} is missing")
    end
    @args[name]
  end

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    Dispatcher::Error.new(text)
  end

end
