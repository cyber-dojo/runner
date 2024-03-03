# frozen_string_literal: true
class ThreaderSynchronous
  attr_reader :called

  def initialize
    @called = false
  end

  def thread(_name, &block)
    @called = true
    block.call
  end
end
