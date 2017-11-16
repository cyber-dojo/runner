require_relative 'http_json_service'

class RunnerService

  def image_pulled?(image_name, kata_id)
    args = [image_name, kata_id]
    get(args, __method__)
  end

  def image_pull(image_name, kata_id)
    args = [image_name, kata_id]
    post(args, __method__)
  end

  # - - - - - - - - - - - - - - - - - - -

  def kata_new(image_name, kata_id)
    args = [image_name, kata_id]
    post(args, __method__)
  end

  def kata_old(image_name, kata_id)
    args = [image_name, kata_id]
    post(args, __method__)
  end

  # - - - - - - - - - - - - - - - - - - -

  def avatar_new(image_name, kata_id, avatar_name, starting_files)
    args = [image_name, kata_id, avatar_name, starting_files]
    post(args, __method__)
  end

  def avatar_old(image_name, kata_id, avatar_name)
    args = [image_name, kata_id, avatar_name]
    post(args, __method__)
  end

  # - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(
    image_name, kata_id, avatar_name,
    new_files, deleted_files, unchanged_files, changed_files,
    max_seconds
  )
    args  = [image_name, kata_id, avatar_name]
    args += [new_files, deleted_files, unchanged_files, changed_files]
    args += [max_seconds]
    post(args, __method__)
  end

  private

  include HttpJsonService

  def hostname
    ENV['CYBER_DOJO_RUNNER_SERVER_NAME']
  end

  def port
    ENV['CYBER_DOJO_RUNNER_SERVER_PORT']
  end

end
