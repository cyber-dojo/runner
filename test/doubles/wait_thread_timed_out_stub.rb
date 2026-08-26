require 'timeout'

class WaitThreadTimedOutStub
  # as returned from process.detach() call

  def initialize(status, joined: true)
    @n = 0
    @value_stubs = {
      1 => -> { raise Timeout::Error }, # .value in main-block
      2 => -> { status }                # .value in ensure block
    }
    # Thread#join(seconds) answers
    #   nil     when the wait runs out, the process is still alive
    #   thread  when the process has exited
    @joined = { true => self, false => nil }[joined]
  end

  def value
    @value_stubs[@n += 1].call
  end

  def join(_seconds)
    @joined
  end
end
