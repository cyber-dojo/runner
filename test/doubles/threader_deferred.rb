class ThreaderDeferred
  # as passed to set_context(threader:), for a test that needs to see the
  # state a service is in while its background work is still going. A real
  # thread would race, and ThreaderSynchronous runs the block before thread
  # answers, so by then the work has already finished and undone itself.
  #
  # This one keeps the block and runs it when the test says so.

  attr_reader :called

  def initialize
    @called = false
    @blocks = []
  end

  def thread(_name, &block)
    @called = true
    @blocks << block
  end

  # How many blocks are waiting, which is how a test says that a second call
  # started no second thread.
  def deferred
    @blocks.size
  end

  # Runs what has been kept, in the order it was given, and forgets it.
  def run_deferred
    blocks = @blocks
    @blocks = []
    blocks.each(&:call)
  end
end
