require_relative './src/external'
require_relative './src/rack_dispatcher'
require_relative './src/rag_lambda_cache'
require_relative './src/runner'
require 'rack'

$stdout.sync = true
$stderr.sync = true

external = External.new
cache = RagLambdaCache.new
runner = Runner.new(external, cache)
run RackDispatcher.new(external, runner, Rack::Request)
