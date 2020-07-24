# frozen_string_literal: true
require_relative '../test_base'
require_source 'http_proxy/json_responder'
require 'json'
require 'ostruct'

module Dual
  class JsonResponderTest < TestBase

    def self.id58_prefix
      'Wh8'
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as0', %w(
    GET response with key matching path,
    returns value associated with the path-key
    ) do
      path = 'tweedle_dee'
      body = JSON.pretty_generate({ path => 42 })
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, nil)
      response = target.get(path, {})
      assert_equal 42, response
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as1', %w(
    POST response with key matching path,
    returns value associated with the path-key
    ) do
      path = 'tweedle_dum'
      body = JSON.pretty_generate({ path => 43 })
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, nil)
      response = target.post(path, {})
      assert_equal 43, response
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as2', %w( raises when response body is not JSON ) do
      path = 'doormouse'
      body = 'abc'
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, DummyError)
      error = assert_raises(DummyError) { target.get(path, {}) }
      assert_equal "http response.body is not JSON:#{body}", error.message
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as3', %w( raises when response body is not JSON Hash ) do
      path = 'alice'
      body = '[]'
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, DummyError)
      error = assert_raises(DummyError) { target.post(path, {}) }
      assert_equal "http response.body is not JSON Hash:#{body}", error.message
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as4', %w(
    raises when response body has 'exception' key,
    (even when there is a key matching the path)
    ) do
      path = 'march_hare'
      body = '{"exception":"Im late", "march_hare":42}'
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, DummyError)
      error = assert_raises(DummyError) { target.get(path, {}) }
      assert_equal '"Im late"', error.message
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    test 'as5', %w(
    raises when response body has no key matching path
    ) do
      path = 'red_queen'
      body = '{}'
      stub = HttpProxyJsonRequesterStub.new(body)
      target = ::HttpProxy::JsonResponder.new(stub, DummyError)
      error = assert_raises(DummyError) { target.post(path, {}) }
      assert_equal "http response.body has no key for 'red_queen':#{body}", error.message
    end

    private

    class HttpProxyJsonRequesterStub
      def initialize(body)
        @body = body
      end
      def get(_path, _args)
        OpenStruct.new(body:@body)
      end
      def post(_path, _args)
        OpenStruct.new(body:@body)
      end
    end

    class DummyError < RuntimeError
      def initialize(message)
        super(message)
      end
    end

  end
end
