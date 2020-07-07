# frozen_string_literal: true

class ProcessAdapterStub

  def initialize
    @stubs = {}
  end

  def method_missing(name, *_args, &block)
    if !block.nil?
      @stubs[name] = block.call
    else
      @stubs[name]
    end
  end

end
