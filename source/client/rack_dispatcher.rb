require 'rack'
require 'json'

class RackDispatcher
  def initialize(context)
    @context = context
  end

  def call(env, request_class = Rack::Request)
    path = request_class.new(env).path_info
    case path
    when '/alive' then json_response(200, { 'alive?' => prober.alive? })
    when '/ready' then json_response(200, { 'ready?' => prober.ready? })
    else json_response(400, { 'exception' => { 'path' => path, 'message' => 'unknown path' } })
    end
  end

  private

  def json_response(status, response)
    [status, CONTENT_TYPE_JSON, [JSON.generate(response)]]
  end

  def prober
    @context.prober
  end

  CONTENT_TYPE_JSON = { 'Content-Type' => 'application/json' }.freeze
end
