require_relative '../test_base'
require_code 'http_proxy/json_requester'
require 'json'
require 'net/http'

class JsonRequesterTest < TestBase

  def self.id58_prefix
    'Wh7'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  class NetHttpAdapterSpy
    def get(uri)
      Net::HTTP::Get.new(uri)
    end
    def post(uri)
      Net::HTTP::Post.new(uri)
    end
    def start(hostname, port, request)
      @hostname = hostname
      @port = port
      @request = request
    end
    attr_reader :hostname, :port, :request
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  test 'as5', %w( get writes json encoded args into request body ) do
    spy = NetHttpAdapterSpy.new
    target = ::HttpProxy::JsonRequester.new(spy, 'differ', 1234)
    path = 'tweedle_dee'
    args = {"arg_1"=>42,"arg_2"=>'9*7'}
    target.get(path, args)

    assert_equal 'differ', spy.hostname
    assert_equal 1234, spy.port
    assert_equal '/'+path, spy.request.path
    assert_equal 'application/json', spy.request.content_type
    assert_equal args, JSON.parse!(spy.request.body)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  test 'as6', %w( post writes json encoded args into request body ) do
    spy = NetHttpAdapterSpy.new
    target = ::HttpProxy::JsonRequester.new(spy, 'saver', 4321)
    path = 'tweedle_dee'
    args = {"arg_1"=>24,"arg_2"=>'7*9'}
    target.post(path, args)

    assert_equal 'saver', spy.hostname
    assert_equal 4321, spy.port
    assert_equal '/'+path, spy.request.path
    assert_equal 'application/json', spy.request.content_type
    assert_equal args, JSON.parse!(spy.request.body)
  end

end
