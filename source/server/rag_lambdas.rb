# frozen_string_literal: true
require 'concurrent'

class RagLambdas
  def initialize
    @map = Concurrent::Map.new
  end

  def [](image_name)
    @map[image_name]
  end

  def compute(image_name, &block)
    @map.compute(image_name, &block)
  end
end
