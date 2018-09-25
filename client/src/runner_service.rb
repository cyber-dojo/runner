require_relative 'http_json_service'

class RunnerService

  def initialize
    @hostname = 'runner-stateless'
    @port = 4597
  end

  def kata_new(image_name, kata_id, starting_files)
    args = [image_name, kata_id, starting_files]
    post(args, __method__)
  end

  def kata_old(image_name, kata_id)
    args = [image_name, kata_id]
    post(args, __method__)
  end

  # - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    image_name, kata_id,
    new_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    args  = [image_name, kata_id]
    args += [new_files, deleted_files, unchanged_files, changed_files]
    args += [max_seconds]
    post(args, __method__)
  end

  private

  include HttpJsonService

  attr_reader :hostname, :port

end
