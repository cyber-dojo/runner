require 'rack'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'
require_relative './src/rack_dispatcher'
require_relative './src/rag_lambda_cache'

use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }
use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter
cache = RagLambdaCache.new
run RackDispatcher.new(cache)
