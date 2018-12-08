require 'ostruct'

class RackRequestStub

  def initialize(env)
    @env = env
  end

  def body
    OpenStruct.new(read:@env[:body])
  end

  def path_info
    "/#{@env[:path_info]}"
  end

end
