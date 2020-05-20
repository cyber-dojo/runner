# frozen_string_literal: true
require_relative 'empty'

class RagLambdaCreator

  class Error < RuntimeError
    def initialize(message, info, source = nil)
      @message = message
      @info = info
      @source = source
      super(message)
    end
    attr_reader :message, :info, :source
  end

  def initialize(external)
    @external = external
  end

  def create(image_name, id)
    files = { 'cyber-dojo.sh' => 'cat /usr/local/bin/red_amber_green.rb' }
    max_seconds = 1
    begin
      result = runner.run_cyber_dojo_sh(image_name, id, files, max_seconds)
    rescue Exception => error
      raise Error.new(error.message, 'runner.run_cyber_dojo_sh() raised an exception')
    end
    begin
      source = result['stdout']['content']
      fn = Empty.binding.eval(source)
    rescue Exception => error
      raise Error.new(error.message, 'eval(lambda) raised an exception', source)
    end
    { source:source, fn:fn }
  end

  private

  def runner
    @external.runner
  end

end
