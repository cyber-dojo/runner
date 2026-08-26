class ProcessSpawner
  def spawn(command, options)
    Process.spawn(command, options)
  end

  def detach(pid)
    Process.detach(pid)
  end
end
