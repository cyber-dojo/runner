require_relative 'externals/bash_sheller'
require_relative 'externals/pipe_maker'
require_relative 'externals/process_spawner'
require_relative 'externals/random'
require_relative 'externals/stdout_logger'
require_relative 'externals/asynchronous_threader'
require_relative 'externals/unix_socket_http'
require_relative 'node'
require_relative 'prober'
require_relative 'puller'
require_relative 'runner'

class Context
  def initialize(options = {})
    @node   = options[:node] || Node.new(self)
    @prober = options[:prober] || Prober.new(self)
    @puller = options[:puller] || Puller.new(self)
    @runner = options[:runner] || Runner.new(self)

    externals(options)
  end

  attr_reader :node, :prober, :puller, :runner, :daemon, :process, :sheller, :threader, :piper, :logger, :random

  # Where the docker daemon listens. The socket is docker's, so the path
  # belongs here at the wiring rather than inside UnixSocketHttp, which knows
  # only how to speak HTTP over a unix socket of any kind.
  DOCKER_SOCKET = '/var/run/docker.sock'.freeze

  private

  # Everything the server reaches the outside world through, and everything a
  # test replaces to keep the outside world out of it.
  def externals(options)
    @daemon   = options[:daemon] || UnixSocketHttp.new(DOCKER_SOCKET)
    @process  = options[:process] || ProcessSpawner.new
    @sheller  = options[:sheller] || BashSheller.new(self)
    @threader = options[:threader] || AsynchronousThreader.new
    @piper    = options[:piper] || PipeMaker.new
    @logger   = options[:logger] || StdoutLogger.new
    @random   = options[:random] || Random.new
  end
end
