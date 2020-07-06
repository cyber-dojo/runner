# frozen_string_literal: true
require_relative 'net_http_adapter'
require_relative 'json_requester'
require_relative 'json_responder'

module HttpProxy
  class LanguagesStartPoints

    class Error < RuntimeError
      def initialize(message)
        super
      end
    end

    def initialize
      adapter = NetHttpAdapter.new
      hostname = 'languages-start-points'
      port = 4524
      requester = JsonRequester.new(adapter, hostname, port)
      @http = JsonResponder.new(requester, Error)
    end

    def names
      @http.get(__method__, {})
    end

    def manifest(name)
      @http.get(__method__, { name:name })
    end

  end
end
