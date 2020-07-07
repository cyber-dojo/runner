
Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner client')
  exit(0)
}

def require_code(name)
  require_relative "code/#{name}"
end

require_code 'context'
require_code 'rack_dispatcher'
context = Context.new
run RackDispatcher.new(context)
