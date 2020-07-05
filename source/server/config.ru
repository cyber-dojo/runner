$stdout.sync = true
$stderr.sync = true

require 'rack'
use Rack::Deflater, if: ->(_, _, _, body) {
  body.any? && body[0].length > 512
}

unless ENV['NO_PROMETHEUS']
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Collector
  use Prometheus::Middleware::Exporter
end

Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner server')
  exit(0)
}

def require_code(name)
  require_relative "code/#{name}"
end

require_code 'externals'
require_code 'rack_dispatcher'

externals = Externals.new
run RackDispatcher.new(externals)
