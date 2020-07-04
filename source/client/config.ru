require 'rack'
require_relative 'code/demo'

Signal.trap('TERM') {
  $stdout.puts('Goodbye from this runner-client')
  exit(0)
}

run Demo.new
