require 'timeout'

class WaitThreadTimedOutStub
  # as returned from process.detach() call

  def initialize(status)
    @n = 0
    @value_stubs = {
      1 => -> { raise Timeout::Error }, # .value in main-block
      2 => -> { status }                # .value in ensure block
    }
  end

  def value
    @value_stubs[@n += 1].call
  end
end
