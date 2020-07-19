# frozen_string_literal: true

class ProcessAdapterStub

  def initialize
    @stubs = {}
  end

  def method_missing(name, *_args)
    if block_given?
      @stubs[name] = yield
    else
      @stubs[name]
    end
  end

end
