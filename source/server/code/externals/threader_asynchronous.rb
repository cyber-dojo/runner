# frozen_string_literal: true

class ThreaderAsynchronous

  def thread(&block)
    Thread.new(&block)
  end

end
