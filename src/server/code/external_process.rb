# frozen_string_literal: true

class ExternalProcess

  def spawn(command, options)
    Process.spawn(command, options)
  end

  def waitpid(pid)
    Process.waitpid(pid)
  end

  def kill(signal, pid)
    Process.kill(signal, pid)
  end

  def detach(pid)
    Process.detach(pid)
  end

end
