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

  def call(env, external = External.new, request = Rack::Request)
    runner = Runner.new(external, @cache)
    name, args = name_args(request.new(env))
    result = runner.public_send(name, *args)
    json_response(200, { name => result })
  rescue => error
    info = {
      'exception' => {
        'class' => error.class.name,
        'message' => error.message,
        'backtrace' => error.backtrace
      }
    }
    $stderr.puts pretty(info)
    $stderr.flush
    json_response(status(error), info)
  end

  private # = = = = = = = = = = = =

  include WellFormedArgs

  def name_args(request)
    name = request.path_info[1..-1] # lose leading /
    well_formed_args(request.body.read)
    args = case name
      when /^sha$/          then []
      when /^kata_new$/     then [image_name, kata_id, starting_files]
      when /^kata_old$/     then [image_name, kata_id]
      when /^run_cyber_dojo_sh$/
        [image_name, kata_id,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
      else
        raise ClientError, 'json:malformed'
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def json_response(status, body)
    [ status, { 'Content-Type' => 'application/json' }, [ pretty(body) ] ]
  end

  def pretty(o)
    JSON.pretty_generate(o)
  end

  def status(error)
    error.is_a?(ClientError) ? 400 : 500
  end

end
