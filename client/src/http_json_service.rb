require 'json'
require 'net/http'

module HttpJsonService # mix-in

  def post(args, method)
    name = method.to_s
    json = http(name, jsoned_args(name, args)) { |uri|
      Net::HTTP::Post.new(uri)
    }
    es_result(json, name)
  end

  def http(method, args)
    uri = URI.parse("http://#{hostname}:#{port}/#{method}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = yield uri.request_uri
    request.content_type = 'application/json'
    request.body = args
    response = http.request(request)
    JSON.parse(response.body)
  end

  def jsoned_args(method, args)
    parameters = self.class.instance_method(method).parameters
    Hash[parameters.map.with_index { |parameter,index|
      [parameter[1], args[index]]
    }].to_json
  end

  def es_result(json, name)
    raise error(name, 'bad json') unless json.class.name == 'Hash'
    exception = json['exception']
    raise error(name, exception)  unless exception.nil?
    raise error(name, 'no key')   unless json.key? name
    json[name]
  end

  def error(name, message)
    StandardError.new("#{self.class.name}:#{name}:#{message}")
  end

end
