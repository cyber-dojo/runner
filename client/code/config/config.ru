Signal.trap('TERM') do
  $stdout.puts('SIGTERM: Goodbye from runner client')
  exit(0)
end

require_relative '../context'
require_relative '../rack_dispatcher'
context = Context.new
run RackDispatcher.new(context)
