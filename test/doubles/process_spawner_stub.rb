# frozen_string_literal: true
class ProcessSpawnerStub
  def initialize
    @stubs = {}
  end

  def method_missing(name, *args, &block)
    if block_given?
      @stubs[name] = block
    else
      @stubs[name].call(*args)
    end
  end
end
