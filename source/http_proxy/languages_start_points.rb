# frozen_string_literal: true
require_relative 'json_requester'
require_relative 'json_responder'
require_relative 'net_http_adapter'

module HttpProxy
  class LanguagesStartPoints

    class Error < RuntimeError
      def initialize(message)
        # :nocov_server:
        super
        # :nocov_server:        
      end
    end

    def initialize
      adapter = ::HttpProxy::NetHttpAdapter.new
      hostname = 'languages-start-points'
      port = 4524
      requester = ::HttpProxy::JsonRequester.new(adapter, hostname, port)
      @http = ::HttpProxy::JsonResponder.new(requester, Error)
    end

    # - - - - - - - - - - - - - - - - - - -

    def alive?
      @http.get(__method__, {})
    end

    def ready?
      @http.get(__method__, {})
    end

    def sha
      @http.get(__method__, {})
    end

    # - - - - - - - - - - - - - - - - - - -

    def manifest(name)
      @http.get(__method__, {
        name:name
      })
    end

  end
end
