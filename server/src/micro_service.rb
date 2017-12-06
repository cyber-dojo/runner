require_relative 'all_avatars_names'
require_relative 'basher'
require_relative 'disk_writer'
require_relative 'ledger_writer'
require_relative 'log_writer'
require_relative 'runner'
require_relative 'valid_image_name'
require 'json'

class MicroService

  def initialize
    @bash   = Basher.new
    @disk   = DiskWriter.new
    @log    = LogWriter.new
    @ledger = LedgerWriter.new
  end

  attr_reader :bash, :disk, :log, :ledger

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
    response = runner.public_send(@name, *@args)
    hash = { @name => response }
    unless log.messages == []
      hash['log'] = log.messages
    end
    if ledger.key?('red_amber_green')
      hash['red_amber_green'] = ledger['red_amber_green']
    end
    [ 200, header_content_json, [ hash.to_json ] ]
  rescue Exception => error
    hash = { 'exception' => error.message }
    # TODO: 200?
    [ 200, header_content_json, [ hash.to_json ] ]
  end

  private # = = = = = = = = = = = =

  def json_args(request)
    args = json_parse(request.body.read)
    unless args.class.name == 'Hash'
      raise RunnerError.new('json:!Hash')
    end
    args
  end

  def json_parse(request)
    JSON.parse(request)
  rescue
    raise RunnerError.new('json:invalid')
  end

  def header_content_json
    { 'Content-Type' => 'application/json' }
  end

  # - - - - - - - - - - - - - - - -
  # method arguments
  # - - - - - - - - - - - - - - - -

  def image_name
    arg = @json_args[__method__.to_s]
    unless valid_image_name?(arg)
      argument_error('image_name', 'invalid')
    end
    arg
  end

  include ValidImageName

  # - - - - - - - - - - - - - - - -

  def kata_id
    arg = @json_args[__method__.to_s]
    unless valid_kata_id?(arg)
      argument_error('kata_id', 'invalid')
    end
    arg
  end

  def valid_kata_id?(kata_id)
    kata_id.class.name == 'String' &&
      kata_id.length == 10 &&
        kata_id.chars.all? { |char| hex?(char) }
  end

  def hex?(char)
    '0123456789ABCDEF'.include?(char)
  end

  # - - - - - - - - - - - - - - - -

  def avatar_name
    arg = @json_args[__method__.to_s]
    unless valid_avatar_name?(arg)
      argument_error('avatar_name', 'invalid')
    end
    arg
  end

  def valid_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

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
    @json_args[__method__.to_s]
  end

  # - - - - - - - - - - - - - - - -

  def argument_error(name, message)
    raise ArgumentError.new("#{name}:#{message}")
  end

end
