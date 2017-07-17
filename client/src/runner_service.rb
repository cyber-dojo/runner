require_relative 'http_service'

class RunnerService

  def image_pulled?(image_name, kata_id)
    get(__method__, image_name, kata_id)
  end

  def image_pull(image_name, kata_id)
    post(__method__, image_name, kata_id)
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
