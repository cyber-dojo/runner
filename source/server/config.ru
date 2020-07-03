$stdout.sync = true
$stderr.sync = true

require 'rack'
use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }

unless ENV['NO_PROMETHEUS']
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Collector
  use Prometheus::Middleware::Exporter
end

Signal.trap('TERM') {
  $stdout.puts('Goodbye from this runner-server')
  exit(0)
}

require_relative 'code/rag_lambdas'
require_relative 'code/rack_dispatcher'
options = { rag_lambdas: RagLambdas.new }
dispatcher = RackDispatcher.new(options)
run dispatcher
