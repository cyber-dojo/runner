require_relative 'client_error'
require_relative 'external'
require_relative 'runner'
require_relative 'well_formed_args'
require 'rack'
require 'json'

class RackDispatcher # stateless

  def initialize(cache)
    @cache = cache
  end

  def call(env, external = External.new, request_class = Rack::Request)
    runner = Runner.new(external, @cache)
    request = request_class.new(env)
    path = request.path_info[1..-1] # lose leading /
    body = request.body.read
    name, args = name_args(path, body)
    result = runner.public_send(name, *args)
    json_response(200, plain({ name => result }))
  rescue => error
    diagnostic = pretty({
      'exception' => {
        'class' => error.class.name,
        'message' => error.message,
        'args' => body,
        'backtrace' => error.backtrace
      }
    })
    $stderr.puts(diagnostic)
    $stderr.flush
    json_response(status(error), diagnostic)
  end

  private # = = = = = = = = = = = =

  include WellFormedArgs

  def name_args(name, body)
    well_formed_args(body)
    args = case name
      when /^sha$/               then []
      when /^kata_new$/          then [image_name, id, starting_files]
      when /^kata_old$/          then [image_name, id]
      when /^run_cyber_dojo_sh$/ then [image_name, id,
                                       new_files, deleted_files,
                                       unchanged_files, changed_files,
                                       max_seconds]
      else
        raise ClientError, 'json:malformed'
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def json_response(status, body)
    [ status,
      { 'Content-Type' => 'application/json' },
      [ body ]
    ]
  end

  def plain(body)
    JSON.generate(body)
  end

  def pretty(body)
    JSON.pretty_generate(body)
  end

  def status(error)
    error.is_a?(ClientError) ? 400 : 500
  end

end
