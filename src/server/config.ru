$stdout.sync = true
$stderr.sync = true

unless ENV['NO_PROMETHEUS']
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Exporter
end

require_relative 'code/rag_lambdas'
require_relative 'code/rack_dispatcher'
require 'rack'
options = { rag_lambdas:RagLambdas.new }
dispatcher = RackDispatcher.new(options)
run dispatcher
