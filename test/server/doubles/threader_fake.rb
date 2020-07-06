# frozen_string_literal: true

class ThreaderFake

  attr_reader :called

  def initialize
    @called = false
  end

  def thread(&block)
    @called = true
    block.call
  end
  
end
