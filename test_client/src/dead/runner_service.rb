require_relative 'http_json_service'

class RunnerService

  def initialize
    @hostname = 'runner-server'
    @port = 4597
  end

  # - - - - - - - - - - - - - - - - - - -

  def sha
    get([], __method__)
  end

  def alive?
    get([], __method__)
  end

  def ready?
    get([], __method__)
  end

  def run_cyber_dojo_sh(image_name, id, files, max_seconds)
    args  = [image_name, id, files, max_seconds]
    get(args, __method__)
  end

  private

  include HttpJsonService

  attr_reader :hostname, :port

end
