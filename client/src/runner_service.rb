require_relative 'http_service'

class RunnerService

  def image_pulled?(image_name)
    get(__method__, image_name)
  end

  def image_pull(image_name)
    post(__method__, image_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def run(image_name, avatar_name, visible_files, max_seconds)
    post(__method__, image_name, avatar_name, visible_files, max_seconds)
  end

  private

  include HttpService
  def hostname; 'runner_stateless'; end
  def port; '4597'; end

end
