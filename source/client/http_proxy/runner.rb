# frozen_string_literal: true
require_relative 'json_requester'
require_relative 'json_responder'
require_relative 'net_http_adapter'

module HttpProxy
  class Runner
    class Error < RuntimeError
    end

    def initialize
      adapter = ::HttpProxy::NetHttpAdapter.new
      hostname = 'runner'
      port = 4597
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

    # - - - - - - - - - - - - - - - - - - - - - - -

    def pull_image(id:, image_name:)
      @http.post(__method__, {
                   id: id,
                   image_name: image_name
                 })
    end

    def run_cyber_dojo_sh(id:, files:, manifest:)
      @http.post(__method__, {
                   id: id,
                   files: files,
                   manifest: manifest
                 })
    end
  end
end
