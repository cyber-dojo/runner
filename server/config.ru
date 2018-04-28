require_relative './src/rack_dispatcher'
require_relative './src/rag_lambda_cache'

$stdout.sync = true
$stderr.sync = true

cache = RagLambdaCache.new
run RackDispatcher.new(cache)
