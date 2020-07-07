# frozen_string_literal: true
require_relative '../http_proxy/json_requester'
require_relative '../http_proxy/json_responder'
require_relative '../http_proxy/net_http_adapter'

class LanguagesStartPointsHttpProxy

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  def initialize
    adapter = HttpProxy::NetHttpAdapter.new
    hostname = 'languages-start-points'
    port = 4524
    requester = HttpProxy::JsonRequester.new(adapter, hostname, port)
    @http = HttpProxy::JsonResponder.new(requester, Error)
  end

  # - - - - - - - - - - - - - - - - - - -

  def ready?
    @http.get(__method__, {})
  end

  # - - - - - - - - - - - - - - - - - - -

  def manifest(name)
    @http.get(__method__, {
      name:name
    })
  end

end
