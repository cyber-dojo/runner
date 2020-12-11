# frozen_string_literal: true

class ThreaderAsynchronous

  def thread(_name, &block)
    Thread.new(&block)
  end

end
