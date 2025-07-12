# frozen_string_literal: true
require 'ostruct'

class RackRequestStub
  def initialize(env)
    @env = env
  end

  def body
    RackRequestBodyStub.new(@env)
  end

  def path_info
    "/#{@env[:path_info]}"
  end
end

class RackRequestBodyStub
  def initialize(env)
    @env = env
  end

  def read
    @env[:body]
  end

  def rewind
  end

end
