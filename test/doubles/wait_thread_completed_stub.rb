# frozen_string_literal: true
class WaitThreadCompletedStub
  def initialize(status)
    @status = status
  end

  def value
    @status
  end
end
