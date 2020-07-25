# frozen_string_literal: true

class ThreadStub
  def initialize(value)
    @value = value
  end
  attr_reader :value
end
