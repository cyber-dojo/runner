require 'rack'
require_relative './src/micro_service'
#require_relative './src/prometheus/collector'
#require_relative './src/prometheus/exporter'

#use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }
#use Prometheus::Middleware::Collector
#use Prometheus::Middleware::Exporter

run MicroService
