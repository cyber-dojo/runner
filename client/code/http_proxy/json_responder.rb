require 'json'

module HttpProxy
  class JsonResponder
    def initialize(requester, exception_class)
      @requester = requester
      @exception_class = exception_class
    end

    # - - - - - - - - - - - - - - - - - - - - -

    def get(path, args)
      response = @requester.get(path, args)
      unpacked(response.body, path.to_s)
    rescue StandardError => e
      raise @exception_class, e.message
    end

    # - - - - - - - - - - - - - - - - - - - - -

    def post(path, args)
      response = @requester.post(path, args)
      unpacked(response.body, path.to_s)
    rescue StandardError => e
      raise @exception_class, e.message
    end

    private

    def unpacked(body, path)
      json = json_parse(body)
      raise error_message(body, 'is not JSON Hash') unless json.is_a?(Hash)
      raise JSON.pretty_generate(json['exception']) if json.has_key?('exception')
      raise error_message(body, "has no key for '#{path}'") unless json.has_key?(path)

      json[path]
    end

    # - - - - - - - - - - - - - - - - - - - - -

    def json_parse(body)
      JSON.parse!(body)
    rescue JSON::ParserError
      raise error_message(body, 'is not JSON')
    end

    # - - - - - - - - - - - - - - - - - - - - -

    def error_message(body, text)
      "http response.body #{text}:#{body}"
    end
  end
end
