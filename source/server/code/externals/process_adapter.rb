# frozen_string_literal: true

class ProcessAdapter

  def detach(pid)
    Process.detach(pid)
  end

  def kill(signal, pid)
    Process.kill(signal, pid)
  end

  def spawn(command, options)
    Process.spawn(command, options)
  end

end
