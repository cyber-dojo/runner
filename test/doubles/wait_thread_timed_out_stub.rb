# frozen_string_literal: true
require 'timeout'

class WaitThreadTimedOutStub
  # as returned from process.detach() call

  def initialize(status, joined)
    @n = 0
    @value_stubs = {
      1 => -> { raise Timeout::Error }, # .value in main-block
      2 => -> { status }                # .value in ensure block
    }
    # @joined controls the (async) result of the process.kill(:TERM, -pid) call
    # Thread.join(n) returns
    #  nil     when the join fails (after n seconds), the kill failed.
    #  thread  when the join succeeds,                the kill succeeded.
    @joined = { true => self, false => nil }[joined]
  end

  def value
    @value_stubs[@n += 1].call
  end

  def join(_seconds)
    @joined
  end
end
