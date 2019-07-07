require_relative 'docker/image_name'
require_relative 'http_json/request_error'
require_relative 'base58'
require 'json'

class HttpJsonArgs

  # Checks for arguments synactic correctness
  # Exception messages use the words 'body' and 'path'
  # to match RackDispatcher's exception keys.

  def initialize(body)
    @args = JSON.parse(body)
    unless @args.is_a?(Hash)
      fail HttpJson::RequestError, 'body is not JSON Hash'
    end
  rescue JSON::ParserError
    fail HttpJson::RequestError, 'body is not JSON'
  end

  # - - - - - - - - - - - - - - - -

  def get(path)
    case path
    when '/ready'              then ['ready?',[]]
    when '/sha'                then ['sha',[]]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh',[image_name, id, files, max_seconds]]
    else
      raise HttpJson::RequestError, 'unknown path'
    end
  end

  private

  def image_name
    name = __method__.to_s
    arg = @args[name]
    unless Docker::image_name?(arg)
      malformed(name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def id
    name = __method__.to_s
    arg = @args[name]
    unless well_formed_id?(arg)
      malformed(name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def files
    name = __method__.to_s
    arg = @args[name]
    unless well_formed_files?(arg)
      malformed(name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def max_seconds
    name = __method__.to_s
    arg = @args[name]
    unless well_formed_max_seconds?(arg)
      malformed(name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def well_formed_id?(arg)
    Base58.string?(arg) && arg.size === 6
  end

  def well_formed_files?(arg)
    arg.is_a?(Hash) && arg.all?{|_f,content| content.is_a?(String) }
  end

  def well_formed_max_seconds?(arg)
    arg.is_a?(Integer) && (1..20).include?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def malformed(arg_name)
    fail HttpJson::RequestError.new("#{arg_name} is malformed")
  end

end
