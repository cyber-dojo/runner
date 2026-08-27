require_relative 'externals/random'
require_relative 'externals/stdout_logger'
require_relative 'externals/asynchronous_threader'
require_relative 'externals/docker_socket'
require_relative 'docker_daemon'
require_relative 'node'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context
  def initialize(options = {})
    # Everything the server reaches the outside world through, and everything a
    # test replaces to keep the outside world out of it.
    @http     = options[:http] || DockerSocket.new
    @threader = options[:threader] || AsynchronousThreader.new
    @logger   = options[:logger] || StdoutLogger.new
    @random   = options[:random] || Random.new

    # The services, which reach the outside world only through those. A
    # DockerDaemon is one of them rather than an external: @http is the object
    # that opens the socket, and DockerDaemon is the only holder of it.
    @docker = options[:docker] || DockerDaemon.new(self)
    @node   = options[:node] || Node.new(self)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)
  end

  attr_reader :node, :prober, :puller, :runner, :docker, :http, :threader, :logger, :random
end
