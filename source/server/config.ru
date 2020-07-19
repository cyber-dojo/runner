$stdout.sync = true
$stderr.sync = true

require 'rack'
use Rack::Deflater, if: ->(_, _, _, body) {
  body.any? && body[0].length > 512
}

unless ENV['USE_PROMETHEUS'] === 'no'
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Collector
  use Prometheus::Middleware::Exporter
end

require_relative 'code/context'
context = Context.new
#context.node.image_names.each do |image_name|
#  context.puller.add(image_name)
#end
#$stdout.puts("#{context.puller.image_names.size} image names added to Puller")

Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner server')
  exit(0)
}

require_relative 'code/rack_dispatcher'
run RackDispatcher.new(context)
