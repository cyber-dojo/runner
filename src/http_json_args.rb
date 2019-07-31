# frozen_string_literal: true

require_relative 'docker/image_name'
require_relative 'http_json/request_error'
require_relative 'base58'
require 'json'

# Checks for arguments synactic correctness
class HttpJsonArgs

  def initialize(body)
    @args = json_parse(body)
    unless @args.is_a?(Hash)
      raise request_error('body is not JSON Hash')
    end
  rescue JSON::ParserError
    raise request_error('body is not JSON')
  end

  # - - - - - - - - - - - - - - - -

  def get(path)
    case path
    when '/sha'                then ['sha',[]]
    when '/alive'              then ['alive?',[]]
    when '/ready'              then ['ready?',[]]
    when '/run_cyber_dojo_sh'  then ['run_cyber_dojo_sh',[image_name, id, files, max_seconds]]
    else
      raise request_error('unknown path')
    end
  end

  private

  def json_parse(body)
    if body === ''
      {}
    else
      JSON.parse(body)
    end
  end

  # - - - - - - - - - - - - - - - -

  def image_name
    checked_arg(:well_formed_image_name?)
  end

  def well_formed_image_name?(arg)
    Docker::image_name?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def id
    checked_arg(:well_formed_id?)
  end

  def well_formed_id?(arg)
    Base58.string?(arg) && arg.size === 6
  end

  # - - - - - - - - - - - - - - - -

  def files
    checked_arg(:well_formed_files?)
  end

  def well_formed_files?(arg)
    arg.is_a?(Hash) && arg.all?{|_f,content| content.is_a?(String) }
  end

  # - - - - - - - - - - - - - - - -

  def max_seconds
    checked_arg(:well_formed_max_seconds?)
  end

  def well_formed_max_seconds?(arg)
    arg.is_a?(Integer) && (1..20).include?(arg)
  end

  # - - - - - - - - - - - - - - - -

  def checked_arg(validator)
    name = caller_locations(1,1)[0].label
    unless @args.has_key?(name)
      raise missing(name)
    end
    arg = @args[name]
    unless self.send(validator, arg)
      raise malformed(name)
    end
    arg
  end

  # - - - - - - - - - - - - - - - -

  def missing(arg_name)
    request_error("#{arg_name} is missing")
  end

  def malformed(arg_name)
    request_error("#{arg_name} is malformed")
  end

  # - - - - - - - - - - - - - - - - -

  def request_error(text)
    # Exception messages use the words 'body' and 'path'
    # to match RackDispatcher's exception keys.
    HttpJson::RequestError.new(text)
  end

end
