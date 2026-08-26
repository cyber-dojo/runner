class WaitThreadCompletedStub
  def initialize(status)
    @status = status
  end

  # Thread#join(seconds) answers the thread when the process has exited.
  def join(_seconds)
    self
  end

  def value
    @status
  end
end
