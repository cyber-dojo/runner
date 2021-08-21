class Node

  def initialize(context)
    @context = context
  end

  def image_names
    command = "docker image ls --format '{{.Repository}}:{{.Tag}}'"
    ls,stderr,status = sheller.capture(command)
    unless status === 0
      raise RuntimeError, stderr
    end
    ls.split("\n").sort.uniq - ['<none>:<none>']
  end

  private

  def sheller
    @context.sheller
  end

end
