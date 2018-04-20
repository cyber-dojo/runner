require_relative './src/rack_dispatcher'
require_relative './src/external'

$stdout.sync = true
$stderr.sync = true

external = External.new
run RackDispatcher.new(external)
