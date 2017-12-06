require_relative 'all_avatars_names'
require_relative 'bash'
require_relative 'disk'
require_relative 'ledger'
require_relative 'runner'
require_relative 'valid_image_name'
require 'json'

class MicroService

  def initialize
    @bash   = Bash.new
    @disk   = Disk.new
    @ledger = Ledger.new
  end

  attr_reader :bash, :disk, :ledger

  def bash=(doppel)
    @bash = doppel
  end

  def call(env, request = Rack::Request.new(env))
    @name = request.path_info[1..-1] # lose leading /
    @json_args = json_args(request)
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
    end
    runner = Runner.new(self, image_name, kata_id)
    result = runner.public_send(@name, *@args)
    body = { @name => result }
    if ledger.key?('red_amber_green')
      body['red_amber_green'] = ledger['red_amber_green']
    end

    [ 200, header_content_is_json, [ body.to_json ] ]

  rescue ShellError => error
    body = { 'exception' => error.args }
    [ 200, header_content_is_json, [ body.to_json ] ]

  rescue => error
    body = { 'exception' => error.message }
    [ 200, header_content_is_json, [ body.to_json ] ]
  end

  private # = = = = = = = = = = = =

  def json_args(request)
    args = json_parse(request.body.read)
    unless args.class.name == 'Hash'
      raise 'json:!Hash'
    end
    args
  end

  def json_parse(request)
    JSON.parse(request)
  rescue
    raise 'json:invalid'
  end

  def header_content_is_json
    { 'Content-Type' => 'application/json' }
  end

  # - - - - - - - - - - - - - - - -
  # method arguments
  # - - - - - - - - - - - - - - - -

  def image_name
    arg = @json_args[__method__.to_s]
    unless valid_image_name?(arg)
      raise invalid('image_name')
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def kata_id
    arg = @json_args[__method__.to_s]
    unless valid_kata_id?(arg)
      raise invalid('kata_id')
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def avatar_name
    arg = @json_args[__method__.to_s]
    unless valid_avatar_name?(arg)
      raise invalid('avatar_name')
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

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
    arg = @json_args[__method__.to_s]
    unless valid_max_seconds?(arg)
      raise invalid('max_seconds')
    end
    arg
  end

  # - - - - - - - - - - - - - - - -
  # validations
  # - - - - - - - - - - - - - - - -

  include ValidImageName

  def valid_kata_id?(kata_id)
    kata_id.class.name == 'String' &&
      kata_id.length == 10 &&
        kata_id.chars.all? { |char| hex?(char) }
  end

  def hex?(char)
    '0123456789ABCDEF'.include?(char)
  end

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

  def valid_max_seconds?(arg)
    arg.class.name == 'Integer' && (1..20).include?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def invalid(name)
    ArgumentError.new("#{name}:invalid")
  end

end
