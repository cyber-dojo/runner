# encoding: UTF-8

require 'benchmark'
require 'prometheus/client'

# Adds dummy image_name labels as experiment.
# If these work as desired in PromQL/grafana
# I will use real image_name labels.

class LabelExperimentCollector
  attr_reader :app, :registry

  def initialize(app, options = {})
    @app = app
    @registry = options[:registry] || Prometheus::Client.registry
    @metrics_prefix = options[:metrics_prefix] || 'http_server'

    init_request_metrics
    init_exception_metrics
  end

  def call(env) # :nodoc:
    trace(env) { @app.call(env) }
  end

  protected

  def init_request_metrics
    @requests = @registry.counter(
      :"#{@metrics_prefix}_requests_total",
      docstring:
        'The total number of HTTP requests handled by the Rack application.',
      labels: %i[code method path]
    )
    @durations = @registry.histogram(
      :"#{@metrics_prefix}_request_duration_seconds",
      docstring: 'The HTTP response duration of the Rack application.',
      labels: %i[method path]
    )
  end

  def init_exception_metrics
    @exceptions = @registry.counter(
      :"#{@metrics_prefix}_exceptions_total",
      docstring: 'The total number of exceptions raised by the Rack application.',
      labels: [:exception]
    )
  end

  def trace(env)
    response = nil
    duration = Benchmark.realtime { response = yield }
    record(env, response.first.to_s, duration)
    return response
  rescue => exception
    @exceptions.increment(labels: { exception: exception.class.name })
    raise
  end

  def record(env, code, duration)
    image_name = "ABC"[rand(3)]
    counter_labels = {
      code:   code,
      method: env['REQUEST_METHOD'].downcase,
      path:   strip_ids_from_path(env['PATH_INFO']),
      image_name: image_name
    }

    duration_labels = {
      method: env['REQUEST_METHOD'].downcase,
      path:   strip_ids_from_path(env['PATH_INFO']),
      image_name: image_name
    }

    @requests.increment(labels: counter_labels)
    @durations.observe(duration, labels: duration_labels)
  rescue
    # TODO: log unexpected exception during request recording
    nil
  end

  def strip_ids_from_path(path)
    path
      .gsub(%r{/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(/|$)}, '/:uuid\\1')
      .gsub(%r{/\d+(/|$)}, '/:id\\1')
  end
end
