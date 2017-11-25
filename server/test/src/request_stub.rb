require 'ostruct'

class RequestStub

  def initialize(body, path_info)
    @body = body
    @path_info = path_info
  end

  def body
    OpenStruct.new(read:@body)
  end

  def path_info
    "/#{@path_info}"
  end

end
