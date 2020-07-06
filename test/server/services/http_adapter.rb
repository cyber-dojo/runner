# frozen_string_literal: true
require 'net/http'

class HttpAdapter

  def get(uri)
    Net::HTTP::Get.new(uri)
  end

  def post(uri)
    Net::HTTP::Post.new(uri)
  end

  def start(hostname, port, req)
    Net::HTTP.start(hostname, port) do |http|
      http.request(req)
    end
  end

end
