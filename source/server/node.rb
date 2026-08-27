class Node
  def initialize(context)
    @context = context
  end

  def image_names
    command = "docker image ls --format '{{.Repository}}:{{.Tag}}'"
    ls, stderr, status = sheller.capture(command)
    raise stderr.to_s unless status.zero?

    # A <none> tag names no image the runner could ever be asked for,
    # whether or not the repository half is set. Both are dropped so that
    # what this answers is only names a manifest could hold.
    ls.split("\n").sort.uniq.reject { |image_name| image_name.end_with?(NO_TAG) }
  end

  private

  NO_TAG = ':<none>'.freeze

  def sheller
    @context.sheller
  end
end
