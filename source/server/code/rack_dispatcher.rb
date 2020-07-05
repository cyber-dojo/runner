# frozen_string_literal: true
require_relative 'http_json_args'
require_relative 'externals'
require 'rack'
require 'json'

class RackDispatcher

  def initialize(options)
    @options = options
  end

  def call(env, request_class = Rack::Request)
    request = request_class.new(env)
    path = request.path_info
    body = request.body.read
    klass,name,args = HttpJsonArgs.new(body).get(path)
    externals = Externals.new(@options)
    result = klass.new(externals).public_send(name, args)
    json_response_pass(200, result)
  rescue HttpJsonArgs::Error => error
    json_response_fail(400, path, body, error)
  rescue Exception => error
    json_response_fail(500, path, body, error)
  end

  private

  def json_response_pass(status, json)
    body = JSON.fast_generate(json)
    [ status, CONTENT_TYPE_JSON, [body] ]
  end

  # - - - - - - - - - - - - - - - -

  def json_response_fail(status, path, body, error)
    json = diagnostic(path, body, error)
    body = JSON.pretty_generate(json)
    Externals.new(@options).stderr.write(body)
    [ status, CONTENT_TYPE_JSON, [body] ]
  end

  # - - - - - - - - - - - - - - - -

  def diagnostic(path, body, error)
    { 'exception' => {
        'path' => path,
        'body' => body,
        'class' => 'Runner',
        'message' => error.message,
        'backtrace' => error.backtrace
      }
    }
  end

  # - - - - - - - - - - - - - - - -

  CONTENT_TYPE_JSON = { 'Content-Type' => 'application/json' }

end
