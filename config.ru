require_relative 'src/external'
require_relative 'src/rack_dispatcher'
require_relative 'src/runner'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'
require 'rack'

use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }
use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter

runner = Runner.new(External.new)
run RackDispatcher.new(runner)
