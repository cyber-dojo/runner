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

require_code 'context'
require_code 'rack_dispatcher'

context = Context.new
unless ENV['NO_PULLER_INITIALIZATION']
  # https://docs.docker.com/engine/reference/commandline/images/#format-the-output
  ls = `docker image ls --format "{{.Repository}}:{{.Tag}}"`
  image_names = ls.split("\n").sort.uniq - ['<none>:<none>']
  image_names.each { |image_name| context.puller.add(image_name) }
  context.logger.write("#{image_names.size} image names added to Puller")
end
run RackDispatcher.new(context)
