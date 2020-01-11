# frozen_string_literal: true

require 'net/http'

class HttpAdapter

  def get(uri)
    KLASS::Get.new(uri)
  end

  def post(uri)
    KLASS::Post.new(uri)
  end

  def start(hostname, port, req)
    KLASS.start(hostname, port) do |http|
      http.request(req)
    end
  end

  private

  KLASS = Net::HTTP

end
