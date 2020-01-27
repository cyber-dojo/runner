$stdout.sync = true
$stderr.sync = true

unless ENV['NO_PROMETHEUS']
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Collector
  use Prometheus::Middleware::Exporter
end

require_relative 'src/externals'
externals = Externals.new
require_relative 'src/rack_dispatcher'
dispatcher = RackDispatcher.new(externals)
require 'rack'
run dispatcher
