# frozen_string_literal: true
require_relative 'http_json/requester'
require_relative 'http_json/responder'

class RunnerHttpProxy

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  def initialize(http)
    requester = HttpJson::Requester.new(http, 'runner-server', 4597)
    @http = HttpJson::Responder.new(requester, Error, { raw:true })
  end

  def alive?
    @http.get(__method__, {})
  end

  def ready?
    @http.get(__method__, {})
  end

  def sha
    @http.get(__method__, {})
  end

  def pull_image(args)
    @http.post(__method__, args)
  end

  def run_cyber_dojo_sh(args)
    @http.post(__method__, args)
  end

end
