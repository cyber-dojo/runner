# frozen_string_literal: true
require_relative 'rag_lambda_creator'
require 'concurrent'

class RagLambdaCache

  # This cache makes quite a difference to speed since
  # a no-op runner call takes typically at least 0.5 seconds

  def initialize(external)
    @external = external
    @cache = Concurrent::Map.new
  end

  def get(image_name, id)
    @cache[image_name] || new_image(image_name, id)
  end

  def new_image(image_name, id)
    @cache.compute(image_name) {
      RagLambdaCreator.new(@external).create(image_name, id)
    }
  end

end
