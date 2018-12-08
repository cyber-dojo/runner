require_relative './src/rack_dispatcher'
require_relative './src/rag_lambda_cache'

cache = RagLambdaCache.new
run RackDispatcher.new(cache)
