# frozen_string_literal: true
require_relative 'test_base'
require 'ostruct'

class HttpProxyJsonResponderTest < TestBase

  def self.id58_prefix
    '375'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '2F0', %w(
  response.body's keyed-value is returned
  when it has a key matching the path
  and raw option is false
  ) do
    args = { 'sha' => sha }
    requester = HttpProxyJsonRequesterStub.new(args.to_json)
    responder = HttpProxy::JsonResponder.new(requester, RunnerErrorStub)
    response = responder.get('sha', nil)
    assert_equal sha, response
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3F0', %w(
  response.body is returned,
  when it has a key matching the path,
  and raw option is true
  ) do
    args = { 'sha' => sha }
    requester = HttpProxyJsonRequesterStub.new(args.to_json)
    responder = HttpProxy::JsonResponder.new(requester, RunnerErrorStub, raw:true)
    response = responder.get('sha', nil)
    assert_equal args, response
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '2F1',
  'raises when response.body is not JSON' do
    assert_responder_raises('xxxx') do |error_message|
      assert_equal 'http response.body is not JSON:xxxx', error_message
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  test '2F2',
  'raises response.body is not JSON Hash' do
    assert_responder_raises('[]') do |error_message|
      assert_equal 'http response.body is not JSON Hash:[]', error_message
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  test '2F3',
  'raises when response.body has embedded exception' do
    json_body = { 'exception' => { 'message' => 'wibble' }}.to_json
    assert_responder_raises(json_body) do |error_message|
      json = JSON.parse(error_message)
      assert_equal 'wibble', json['message']
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  test '2F4',
  'raises when response.body has no key matching path' do
    json_body = { 'not_sha' => 'hello' }.to_json
    assert_responder_raises(json_body, 'sha') do |error_message|
      expected = "http response.body has no key for 'sha':{\"not_sha\":\"hello\"}"
      assert_equal expected, error_message
    end
  end

  private

  class HttpProxyJsonRequesterStub
    def initialize(body)
      @body = body
    end
    def get(_path,_args)
      OpenStruct.new(body:@body)
    end
  end

  class RunnerErrorStub < RuntimeError
    def initialize(message)
      super
    end
  end

  def assert_responder_raises(json_body, path=nil)
    requester = HttpProxyJsonRequesterStub.new(json_body)
    responder = HttpProxy::JsonResponder.new(requester, RunnerErrorStub)
    error = assert_raises(RunnerErrorStub) {
      responder.get(path, nil)
    }
    yield error.message
  end

  def sha
    '0e5c2a24ad27446f97ebf5d8176662560582d449'
  end

end
