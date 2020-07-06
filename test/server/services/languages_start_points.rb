# frozen_string_literal: true
require_relative 'http_adapter'
require_relative 'http_json/service'

class LanguagesStartPoints

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  def initialize
    adapter = HttpAdapter.new
    @http = HttpJson::service(adapter, 'languages-start-points', 4524, Error)
  end

  def names
    @http.get(__method__, {})
  end

  def manifest(name)
    @http.get(__method__, { name:name })
  end

end
