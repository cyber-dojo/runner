class ProcessSpawner

  def spawn(command, options)
    Process.spawn(command, options)
  end

  def detach(pid)
    Process.detach(pid)
  end

  def kill(signal, pid)
    Process.kill(signal, pid)
  end

end
