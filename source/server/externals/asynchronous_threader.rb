# frozen_string_literal: true
class AsynchronousThreader
  def thread(name, &block)
    Thread.new(name, &block)
  end
end
