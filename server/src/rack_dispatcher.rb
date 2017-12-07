require_relative 'all_avatars_names'
require_relative 'bash'
require_relative 'disk'
require_relative 'ledger'
require_relative 'runner'
require_relative 'valid_image_name'
require 'json'

class RackDispatcher

  def initialize(request = Rack::Request)
    @request = request
    @bash   = Bash.new
    @disk   = Disk.new
    @ledger = Ledger.new
  end

  attr_reader :bash, :disk, :ledger

  def bash=(doppel)
    @bash = doppel
  end

  def call(env)
    request = @request.new(env)
    name, args = validated_name_args(request)
    runner = Runner.new(self, image_name, kata_id)
    result = runner.public_send(name, *args)
    body = { name => result }
    if ledger.key?('red_amber_green')
      body['red_amber_green'] = ledger['red_amber_green']
    end
    triple(body)
  rescue ShellError => error
    triple({ 'exception' => error.args })
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
      when /^image_pulled$/ then []
      when /^image_pull$/   then []
      when /^kata_new$/     then []
      when /^kata_old$/     then []
      when /^avatar_new$/   then [avatar_name, starting_files]
      when /^avatar_old$/   then [avatar_name]
      when /^run_cyber_dojo_sh$/
        [avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
    end
    name += '?' if name == 'image_pulled'
    [name, args]
  end

  def json_parse(request)
    JSON.parse(request)
  rescue
    raise 'json:invalid'
  end

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
      raise invalid('image_name')
    end
    arg
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - -

  def validated_kata_id
    arg = @json_args['kata_id']
    unless valid_kata_id?(arg)
      raise invalid('kata_id')
    end
    arg
  end

  def valid_kata_id?(kata_id)
    kata_id.is_a?(String) &&
      kata_id.length == 10 &&
        kata_id.chars.all? { |char| hex?(char) }
  end

  def hex?(char)
    '0123456789ABCDEF'.include?(char)
  end

  # - - - - - - - - - - - - - - - -

  def validated_avatar_name
    arg = @json_args['avatar_name']
    unless valid_avatar_name?(arg)
      raise invalid('avatar_name')
    end
    arg
  end

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

  def validated_files(arg_name)
    arg_name = arg_name.to_s
    arg = @json_args[arg_name]
    unless valid_files?(arg)
      raise invalid(arg_name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def valid_files?(arg)
    arg.is_a?(Hash) &&
      arg.all? { |k,v| k.is_a?(String) && v.is_a?(String) }
  end

  # - - - - - - - - - - - - - - - -

  def validated_max_seconds
    arg = @json_args['max_seconds']
    unless valid_max_seconds?(arg)
      raise invalid('max_seconds')
    end
    arg
  end

  def valid_max_seconds?(arg)
    arg.is_a?(Integer) && (1..20).include?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def invalid(name)
    ArgumentError.new("#{name}:invalid")
  end

end
