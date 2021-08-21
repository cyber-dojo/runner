require 'net/http'

module HttpProxy

  class NetHttpAdapter

    def get(uri)
      Net::HTTP::Get.new(uri)
    end

    def post(uri)
      # :nocov_server:
      Net::HTTP::Post.new(uri)
      # :nocov_server:
    end

    def start(hostname, port, req)
      Net::HTTP.start(hostname, port) do |http|
        http.request(req)
      end
    end

  end
  
end
