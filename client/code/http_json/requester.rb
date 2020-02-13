# frozen_string_literal: true
require 'json'
require 'uri'

module HttpJson

  class Requester

    def initialize(http, hostname, port)
      @http = http
      @hostname = hostname
      @port = port
    end

    def get(path, args)
      request(path, args) do |uri|
        @http.get(uri)
      end
    end

    private

    def request(path, args)
      uri = URI.parse("http://#{@hostname}:#{@port}/#{path}")
      req = yield uri
      req.content_type = 'application/json'
      req.body = JSON.fast_generate(args)
      @http.start(@hostname, @port, req)
    end

  end

end
