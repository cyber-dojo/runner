# frozen_string_literal: true

class ExternalThreader

  def thread(&block)
    Thread.new(&block)
  end

end
