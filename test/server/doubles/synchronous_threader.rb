# frozen_string_literal: true

class SynchronousThreader

  attr_reader :called

  def initialize
    @called = false
  end

  def thread(&block)
    @called = true
    block.call
  end

end
