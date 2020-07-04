require 'rack'
require_relative 'code/demo'

Signal.trap('TERM') {
  $stdout.puts('SIGTERM: Goodbye from runner client')
  exit(0)
}

run Demo.new
