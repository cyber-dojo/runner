require_relative 'well_formed_args'

class RackDispatcher # stateless

  def initialize(external, runner, request)
    @external = external
    @runner = runner
    @request = request
  end

  def call(env)
    request = @request.new(env)
    name, args = name_args(request)
    triple(success, {
      name => @runner.public_send(name, *args)
    })
  rescue => error
    log(error)
    triple(code(error), {
      'exception' => error.message,
      'trace' => error.backtrace
    })
  end

  private # = = = = = = = = = = = =

  include WellFormedArgs

  def name_args(request)
    name = request.path_info[1..-1] # lose leading /
    well_formed_args(request.body.read)
    args = case name
      when /^kata_new$/,
           /^kata_old$/     then [image_name, kata_id]
      when /^avatar_new$/   then [image_name, kata_id, avatar_name, starting_files]
      when /^avatar_old$/   then [image_name, kata_id, avatar_name]
      when /^run_cyber_dojo_sh$/
        [image_name, kata_id, avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
      else
        raise ClientError, 'json:malformed'
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def success
    200
  end

  def code(error)
    error.is_a?(ClientError) ? 400 : 500
  end

  def triple(code, body)
    [ code, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

  # - - - - - - - - - - - - - - - -

  def log(error)
    @external.log << error.message
    error.backtrace.each { |line| @external.log << line }
  rescue => e
    puts e.class.name
    puts e.message
  end

end
