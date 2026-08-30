require_relative 'externals/monotonic_clock'
require_relative 'externals/random'
require_relative 'externals/stdout_logger'
require_relative 'externals/asynchronous_threader'
require_relative 'externals/docker_socket'
require_relative 'cyber_dojo_sh_runner'
require_relative 'docker_daemon'
require_relative 'prober'
require_relative 'node_images'
require_relative 'runner'

class Context
  def initialize(options = {})
    # Everything the server reaches the outside world through, and
    # everything a test replaces to keep the outside world out of it.
    @clock    = options[:clock] || MonotonicClock.new
    @http     = options[:http] || DockerSocket.new
    @logger   = options[:logger] || StdoutLogger.new
    @random   = options[:random] || Random.new
    @threader = options[:threader] || AsynchronousThreader.new

    # The services, which reach the outside world only through those. A
    # DockerDaemon is one of them rather than an external: @http is the object
    # that opens the socket, and DockerDaemon is the only holder of it.
    @docker = options[:docker] || DockerDaemon.new(self)
    @images = options[:images] || NodeImages.new(self)
    @prober = options[:prober] || Prober.new(self)
    @runner = options[:runner] || Runner.new(self)

    # One run of a kata's cyber-dojo.sh, answering what the container sent
    # back. Named apart from :runner because what runs the container is the
    # part being replaced, and holding it here is what lets a replacement be
    # swapped in the way a test swaps :http. See
    # docs/dropping-the-docker-daemon.md, whose step 8 retires this entry once
    # only one implementation is left.
    @test_run = options[:test_run] || CyberDojoShRunner.new(self)
  end

  # What the server reaches the outside world through.
  attr_reader :clock, :http, :logger, :random, :threader

  # The services, which reach it only through those.
  attr_reader :docker, :images, :prober, :runner, :test_run
end
