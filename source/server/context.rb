require_relative 'externals/monotonic_clock'
require_relative 'externals/random'
require_relative 'externals/stdout_logger'
require_relative 'externals/asynchronous_threader'
require_relative 'externals/docker_socket'
require_relative 'docker_daemon'
require_relative 'prober'
require_relative 'node_images'
require_relative 'node_spares'
require_relative 'runner'
require_relative 'spare_pool'

class Context
  def initialize(options = {})
    # Everything the server reaches the outside world through, and
    # everything a test replaces to keep the outside world out of it.
    @clock    = options[:clock] || MonotonicClock.new
    @http     = options[:http] || DockerSocket.new
    @logger   = options[:logger] || StdoutLogger.new
    # The store of spares, which is a directory rather than anything in this
    # process, so that every worker on the node reads the one store. A test
    # gives it a directory of its own, the way one gives DockerSocket a
    # socket of its own.
    @node_spares = options[:node_spares] || NodeSpares.new(dir: NodeSpares::DIR)
    # How many spares the node may hold. Zero is no pool at all, and is what a
    # Context gets unless it is told otherwise. config.ru tells it, from the
    # environment, so this file reads nothing from outside.
    @spares_per_node = options[:spares_per_node] || 0
    @random   = options[:random] || Random.new
    @threader = options[:threader] || AsynchronousThreader.new

    # The services, which reach the outside world only through those. A
    # DockerDaemon is one of them rather than an external: @http is the object
    # that opens the socket, and DockerDaemon is the only holder of it.
    @docker = options[:docker] || DockerDaemon.new(self)
    @images = options[:images] || NodeImages.new(self)
    @prober = options[:prober] || Prober.new(self)
    @runner = options[:runner] || Runner.new(self)
    @spares = options[:spares] || SparePool.new(self)
  end

  # What the server reaches the outside world through.
  attr_reader :clock, :http, :logger, :node_spares, :random, :spares_per_node, :threader

  # The services, which reach it only through those.
  attr_reader :docker, :images, :prober, :runner, :spares
end
