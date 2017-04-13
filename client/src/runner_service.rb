require_relative 'http_service'

class RunnerService

  def image_pulled?(image_name)
    get(__method__, image_name)
  end

  def image_pull(image_name)
    post(__method__, image_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def kata_new(image_name, kata_id)
    post(__method__, image_name, kata_id)
  end

  def kata_old(image_name, kata_id)
    post(__method__, image_name, kata_id)
  end

  # - - - - - - - - - - - - - - - - - - -

  def avatar_new(image_name, kata_id, avatar_name, starting_files)
    post(__method__, image_name, kata_id, avatar_name, starting_files)
  end

  def avatar_old(image_name, kata_id, avatar_name)
    post(__method__, image_name, kata_id, avatar_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def run(image_name, kata_id, avatar_name, visible_files, max_seconds)
    args = [image_name, kata_id, avatar_name]
    args += [visible_files, max_seconds]
    post(__method__, *args)
  end

  private

  include HttpService
  def hostname; 'runner_stateless'; end
  def port; '4597'; end

end
