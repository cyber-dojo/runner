
Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner client')
  exit(0)
}

require_relative '../app/context'
require_relative '../app/rack_dispatcher'
context = Context.new
run RackDispatcher.new(context)
