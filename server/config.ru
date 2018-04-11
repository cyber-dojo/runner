require_relative './src/rack_dispatcher'

$stdout.sync = true
$stderr.sync = true

run RackDispatcher.new
