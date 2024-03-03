# frozen_string_literal: true
require 'json'

class Dispatcher
  class RequestError < RuntimeError
  end

  def initialize(context)
    @context = context
  end

  def call(path, body)
    args = parse_json_args(body)
    case path
    when '/sha'                then ['sha',               prober.sha(**args)]
    when '/alive'              then ['alive?',            prober.alive?(**args)]
    when '/ready'              then ['ready?',            prober.ready?(**args)]
    when '/pull_image'         then ['pull_image',        runner.pull_image(**args)]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh', runner.run_cyber_dojo_sh(**args)]
    else
      raise request_error('unknown path')
    end
  rescue JSON::JSONError
    raise request_error('body is not JSON')
  rescue Exception => e
    if r = e.message.match('(missing|unknown) keyword(s?): (.*)')
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
      json.transform_keys { |key| key.to_sym }
    end
  end

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    Dispatcher::RequestError.new(text)
  end

  def prober
    @context.prober
  end

  def runner
    @context.runner
  end
end
