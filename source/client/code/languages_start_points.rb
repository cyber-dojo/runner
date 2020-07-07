# frozen_string_literal: true
require_relative 'http_proxy/json_requester'
require_relative 'http_proxy/json_responder'
require_relative 'http_proxy/net_http_adapter'

class LanguagesStartPoints

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  def initialize(hostname, port)
    adapter = HttpProxy::NetHttpAdapter.new
    hostname = 'languages-start-points'
    port = 4524
    requester = HttpProxy::JsonRequester.new(adapter, hostname, port)
    @http = HttpProxy::JsonResponder.new(requester, Error)
  end

  def manifest(name)
    @http.get(__method__, {
      name:name
    })
  end

end
