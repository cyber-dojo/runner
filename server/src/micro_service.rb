require_relative 'externals'
require_relative 'runner'
require 'json'

class MicroService

  include Externals

  def call(env, request = Rack::Request.new(env))
    @json_args = json_args(request)
    @name = request.path_info[1..-1] # lose leading /
    @args = case @name
      when /^image_pulled$/
        @name += '?'
        []
      when /^image_pull$/   then []
      when /^kata_new$/     then []
      when /^kata_old$/     then []
      when /^avatar_new$/   then [avatar_name, starting_files]
      when /^avatar_old$/   then [avatar_name]
      when /^run_cyber_dojo_sh$/
        [avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
      else
        @name = nil
        []
      end
    [ 200, { 'Content-Type' => 'application/json' }, [ invoke.to_json ] ]
  end

  private # = = = = = = = = = = = =

  def invoke
    runner = Runner.new(self, image_name, kata_id)
    { @name => runner.public_send(@name, *@args) }
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{@name} #{e.message}"
    { 'exception' => e.message }
  end

  # - - - - - - - - - - - - - - - -

  def json_args(request)
    args = JSON.parse(request.body.read)
    if args.nil? # JSON.parse('null') => nil
      #TODO: log << ...
      args = {}
    end
    if args.class.name == 'Array' # Hash please
      #TODO: log << ...
      args = {}
    end
    args
  rescue StandardError => e
    log << "EXCEPTION: #{e.class.name}.#{__method__} #{e.message}"
    {}
  end

  # - - - - - - - - - - - - - - - -

  def image_name
    @json_args[__method__.to_s]
  end

  def kata_id
    @json_args[__method__.to_s]
  end

  def avatar_name
    @json_args[__method__.to_s]
  end

  def starting_files
    @json_args[__method__.to_s]
  end

  def new_files
    @json_args[__method__.to_s]
  end

  def deleted_files
    @json_args[__method__.to_s]
  end

  def unchanged_files
    @json_args[__method__.to_s]
  end

  def changed_files
    @json_args[__method__.to_s]
  end

  def max_seconds
    @json_args[__method__.to_s]
  end

end
