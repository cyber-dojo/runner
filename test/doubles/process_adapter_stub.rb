# frozen_string_literal: true

class ProcessAdapterStub

  def initialize
    @stubs = {}
  end

  def method_missing(name, *_args, &block)
    if block_given?
      @stubs[name] = block
    else
      @stubs[name].call
    end
  end

end
