$stdout.sync = true
$stderr.sync = true

Signal.trap('TERM') do
  $stdout.puts('SIGTERM: Goodbye from runner server')
  exit(0)
end

if ENV['CYBER_DOJO_PROMETHEUS'] === 'true'
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  use Prometheus::Middleware::Collector
  use Prometheus::Middleware::Exporter
end

use_containerd = ENV['CYBER_DOJO_USE_CONTAINERD'] === 'true'
$stdout.puts("CYBER_DOJO_USE_CONTAINERD:#{use_containerd}")

require 'rack'
use Rack::Deflater, if: lambda { |_, _, _, body|
  body.any? && body[0].length > 512
}

require_relative '../context'
context = Context.new
context.node.image_names.each do |image_name|
  context.puller.add(image_name)
end
$stdout.puts("#{context.puller.image_names.size} image names added to Puller")

require_relative '../rack_dispatcher'
run RackDispatcher.new(context)
