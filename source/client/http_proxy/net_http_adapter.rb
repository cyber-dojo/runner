require 'net/http'

module HttpProxy
  class NetHttpAdapter
    def get(uri)
      Net::HTTP::Get.new(uri)
    end

    def post(uri)
      # simplecov:disable
      Net::HTTP::Post.new(uri)
      # simplecov:enable
    end

    def start(hostname, port, req)
      Net::HTTP.start(hostname, port) do |http|
        http.request(req)
      end
    end
  end
end
