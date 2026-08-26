class WaitThreadTimedOutStub
  # as returned from process.detach() call

  # Thread#join(seconds) answers
  #   nil     when the wait runs out, the process is still alive
  #   thread  when the process has exited
  # The first join is the max_seconds wait, which times out here. The second
  # is the grace given to the docker stop, which @joined decides.
  def initialize(status, joined: true)
    @status = status
    @n = 0
    @join_stubs = {
      1 => nil,
      2 => { true => self, false => nil }[joined]
    }
    @join_seconds = []
  end

  attr_reader :join_seconds

  def join(seconds)
    @join_seconds << seconds
    @join_stubs[@n += 1]
  end

  def value
    @status
  end
end
