require_relative 'base58'
require_relative 'external'
require_relative 'runner'
require_relative 'valid_avatar_name'
require_relative 'valid_image_name'
require 'json'
require 'rack'

class RackDispatcher # stateless

  def initialize(request = Rack::Request)
    @request = request
    @external = External.new
  end

  attr_reader :external

  def call(env)
    request = @request.new(env)
    name, args = validated_name_args(request)
    runner = Runner.new(external)
    triple({ name => runner.public_send(name, *args) })
  rescue => error
    triple({ 'exception' => error.message })
  end

  private # = = = = = = = = = = = =

  def validated_name_args(request)
    name = request.path_info[1..-1] # lose leading /
    @json_args = json_parse(request.body.read)
    unless @json_args.is_a?(Hash)
      raise 'json:!Hash'
    end
    args = case name
      when /^kata_new$/,
           /^kata_old$/     then [image_name, kata_id]
      when /^avatar_new$/   then [image_name, kata_id, avatar_name, starting_files]
      when /^avatar_old$/   then [image_name, kata_id, avatar_name]
      when /^run_cyber_dojo_sh$/
        [image_name, kata_id, avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def json_parse(request)
    JSON.parse(request)
  rescue
    raise 'json:invalid'
  end

  # - - - - - - - - - - - - - - - -

  def triple(body)
    [ 200, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

  # - - - - - - - - - - - - - - - -
  # method arguments
  # - - - - - - - - - - - - - - - -

  def image_name
    validated_image_name
  end

  def kata_id
    validated_kata_id
  end

  def avatar_name
    validated_avatar_name
  end

  def starting_files
    validated_files(__method__)
  end

  def new_files
    validated_files(__method__)
  end

  def deleted_files
    validated_files(__method__)
  end

  def unchanged_files
    validated_files(__method__)
  end

  def changed_files
    validated_files(__method__)
  end

  def max_seconds
    validated_max_seconds
  end

  # - - - - - - - - - - - - - - - -
  # validations
  # - - - - - - - - - - - - - - - -

  def validated_image_name
    arg = @json_args['image_name']
    unless valid_image_name?(arg)
      invalid('image_name')
    end
    arg
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - -

  def validated_kata_id
    arg = @json_args['kata_id']
    unless valid_kata_id?(arg)
      invalid('kata_id')
    end
    arg
  end

  def valid_kata_id?(kata_id)
    Base58.string?(kata_id) && kata_id.size == 10
  end

  # - - - - - - - - - - - - - - - -

  def validated_avatar_name
    arg = @json_args['avatar_name']
    unless valid_avatar_name?(arg)
      invalid('avatar_name')
    end
    arg
  end

  include ValidAvatarName

  # - - - - - - - - - - - - - - - -

  def validated_files(arg_name)
    arg_name = arg_name.to_s
    arg = @json_args[arg_name]
    unless valid_files?(arg)
      invalid(arg_name)
    end
    arg
  end

  def valid_files?(arg)
    arg.is_a?(Hash) &&
      arg.all? { |k,v| k.is_a?(String) && v.is_a?(String) }
  end

  # - - - - - - - - - - - - - - - -

  def validated_max_seconds
    arg = @json_args['max_seconds']
    unless valid_max_seconds?(arg)
      invalid('max_seconds')
    end
    arg
  end

  def valid_max_seconds?(arg)
    arg.is_a?(Integer) && (1..20).include?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def invalid(name)
    raise ArgumentError.new("#{name}:invalid")
  end

end
