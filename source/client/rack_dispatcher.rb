# frozen_string_literal: true
require_relative 'dispatcher'
require 'rack'
require 'json'

class RackDispatcher
  def initialize(context)
    @context = context
    @dispatcher = Dispatcher.new(context)
  end

  def call(env, request_class = Rack::Request)
    request = request_class.new(env)
    path = request.path_info
    body = request.body.read
    name, result = @dispatcher.call(path, body)
    json_response_pass(200, { name => result })
  rescue Dispatcher::RequestError => e
    json_response_fail(400, path, body, e)
  rescue Exception => e
    json_response_fail(500, path, body, e)
  end

  private

  def json_response_pass(status, response)
    json = JSON.generate(response)
    [status, CONTENT_TYPE_JSON, [json]]
  end

  # - - - - - - - - - - - - - - - -

  def json_response_fail(status, path, body, error)
    response = diagnostic(path, body, error)
    json = JSON.pretty_generate(response)
    $stdout.write(json)
    [status, CONTENT_TYPE_JSON, [json]]
  end

  # - - - - - - - - - - - - - - - -

  def diagnostic(path, body, error)
    { 'exception' => {
      'path' => path,
      'body' => body,
      'class' => 'Client',
      'message' => error.message,
      'backtrace' => error.backtrace
    } }
  end

  # - - - - - - - - - - - - - - - -

  CONTENT_TYPE_JSON = { 'Content-Type' => 'application/json' }.freeze
end
