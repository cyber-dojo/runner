# frozen_string_literal: true
class ThreadValueStub
  def initialize(value)
    @value = value
  end

  attr_reader :value
end
