# frozen_string_literal: true

class AsynchronousThreader

  def thread(&block)
    Thread.new(&block)
  end

end
