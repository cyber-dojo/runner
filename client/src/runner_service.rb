require_relative 'http_json_service'

class RunnerService

  def initialize
    @hostname = 'runner-stateless'
    @port = 4597
  end

  # - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    image_name, id,
    created_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    args  = [image_name, id]
    args += [created_files, deleted_files, unchanged_files, changed_files]
    args += [max_seconds]
    post(args, __method__)
  end

  private

  include HttpJsonService

  attr_reader :hostname, :port

end
