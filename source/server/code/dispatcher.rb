# frozen_string_literal: true
require_relative 'externals'
require_relative 'prober'
require_relative 'runner'
require 'json'

class Dispatcher

  class RequestError < RuntimeError
    def initialize(message)
      super
    end
  end

  # - - - - - - - - - - - - - - - -

  def initialize(externals)
    @prober = externals.prober    
    @runner = externals.runner
  end

  # - - - - - - - - - - - - - - - -

  def call(path, body)
    args = parse_json_args(body)
    case path
    when '/sha'                then ['sha',    @prober.sha(**args)]
    when '/alive'              then ['alive?', @prober.alive?(**args)]
    when '/ready'              then ['ready?', @prober.ready?(**args)]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh', @runner.run_cyber_dojo_sh(**args)]
    else raise request_error('unknown path')
    end
  rescue JSON::JSONError
    raise request_error('body is not JSON')
  rescue Exception => caught
    if r = caught.message.match('(missing|unknown) keyword(s?): (.*)')
      raise request_error("#{r[1]} argument#{r[2]}: #{r[3]}")
    end
    raise
  end

  private

  def parse_json_args(body)
    args = {}
    unless body === ''
      json = JSON.parse!(body)
      unless json.is_a?(Hash)
        raise request_error('body is not JSON Hash')
      end
      # double-splat requires top-level symbol keys
      json.each { |key,value| args[key.to_sym] = value }
    end
    args
  end

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    Dispatcher::RequestError.new(text)
  end

end
