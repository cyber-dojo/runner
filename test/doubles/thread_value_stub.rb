class ThreadValueStub
  def initialize(value)
    @value = value
  end

  attr_reader :value

  # A stub thread already holding its value has finished, and Thread#join
  # answers the thread when it has.
  def join(_seconds)
    self
  end
end
