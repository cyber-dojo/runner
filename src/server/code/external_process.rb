# frozen_string_literal: true

class ExternalProcess

  def initialize(_externals)
  end

  def spawn(command, options)
    Process.spawn(command, options)
  end

  def waitpid2(pid)
    Process.waitpid2(pid)
  end

  def kill(signal, pid)
    Process.kill(signal, pid)
  end

  def detach(pid)
    Process.detach(pid)
  end

end
