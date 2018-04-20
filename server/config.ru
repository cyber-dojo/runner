require_relative './src/external'
require_relative './src/rack_dispatcher'
require_relative './src/runner'

$stdout.sync = true
$stderr.sync = true

external = External.new
runner = Runner.new(external)
run RackDispatcher.new(runner)
