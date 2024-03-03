# frozen_string_literal: true
require 'ostruct'

class RackRequestStub
  def initialize(env)
    @env = env
  end

  def body
    Struct.new(:read).new(@env[:body])
  end

  def path_info
    "/#{@env[:path_info]}"
  end
end
