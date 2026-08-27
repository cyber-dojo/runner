require 'json'

class Node
  def initialize(context)
    @context = context
  end

  def image_names
    code, body = daemon.request('GET', '/images/json')
    raise body.to_s unless code == 200

    # One image can carry several RepoTags, and an image carrying none names
    # nothing a manifest could hold, so flattening is all the filtering needed.
    JSON.parse(body).flat_map { |image| image['RepoTags'] }.sort
  end

  private

  def daemon
    @context.daemon
  end
end
