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

Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner server')
  exit(0)
}

def require_code(name)
  require_relative "code/#{name}"
end

def node_image_names
  ls = `docker image ls --format "{{.Repository}}:{{.Tag}}"`
  ls.split("\n").sort.uniq - ['<none>:<none>']
end

def do_puller_setup(puller, image_names)
  image_names.each { |image_name| puller.add(image_name) }
  $stdout.puts("#{image_names.size} image names added to Puller")
end

require_code 'context'
require_code 'rack_dispatcher'

context = Context.new
unless ENV['DO_PULLER_SETUP'] === 'no'
  do_puller_setup(context.puller, node_image_names)
end
run RackDispatcher.new(context)
