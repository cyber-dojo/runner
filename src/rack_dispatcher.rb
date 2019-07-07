require_relative 'http_json/request_error'
require_relative 'http_json_args'
require 'rack'
require 'json'

class RackDispatcher

  def initialize(runner)
    @runner = runner
  end

  def call(env, request_class = Rack::Request)
    request = request_class.new(env)
    path = request.path_info
    body = request.body.read
    name,args = HttpJsonArgs.new(body).get(path)
    result = @runner.public_send(name, *args)
    json_response(200, { name => result })
  rescue HttpJson::RequestError => error
    json_response(400, diagnostic(path, body, error))
  rescue Exception => error
    json_response(500, diagnostic(path, body, error))
  end

  private

  def json_response(status, json)
    if status == 200
      body = JSON.fast_generate(json)
    else
      body = JSON.pretty_generate(json)
      $stderr.puts(body)
      $stderr.flush
    end
    [ status,
      { 'Content-Type' => 'application/json' },
      [ body ]
    ]
  end

  # - - - - - - - - - - - - - - - -

  def diagnostic(path, body, error)
    { 'exception' => {
        'path' => path,
        'body' => body,
        'class' => 'RunnerService',
        'message' => error.message,
        'backtrace' => error.backtrace
      }
    }
  end

end
