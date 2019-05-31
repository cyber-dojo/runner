require_relative 'base58'
require_relative 'client_error'
require_relative 'image_name'
require 'json'

# Checks for arguments syntactic correctness

module WellFormedArgs

  def well_formed_args(s)
    @args = JSON.parse(s)
    if @args.nil? || !@args.is_a?(Hash)
      malformed('json')
    end
  rescue
    malformed('json')
  end

  # - - - - - - - - - - - - - - - -

  def image_name
    name = __method__.to_s
    arg = @args[name]
    unless image_name?(arg)
      malformed(name)
    end
    arg
  end

  include ImageName

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

  private # = = = = = = = = = = = =

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
    raise ClientError, "#{arg_name}:malformed"
  end

end
