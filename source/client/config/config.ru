
Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner client')
  exit(0)
}

require_relative '../code/context'
require_relative '../code/rack_dispatcher'
context = Context.new
run RackDispatcher.new(context)
