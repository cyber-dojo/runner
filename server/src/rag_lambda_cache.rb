# Caching the rag-lambdas typically saves
# about 0.15 seconds per [test] event.

class RagLambdaCache

  def initialize
    @cache = {}
  end

  def rag_lambda(image_name, &block)
    @cache[image_name] ||= block.call
  end

end
