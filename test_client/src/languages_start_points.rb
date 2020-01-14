# frozen_string_literal: true

require_relative 'http_json/service'

class LanguagesStartPoints

  class Error < RuntimeError
    def initialize(message)
      super
    end
  end

  def initialize(http)
    @http = HttpJson::service(http, 'languages-start-points', 4524, Error)
  end

  def manifest(name)
    @http.get(__method__, { name:name })
  end

end
