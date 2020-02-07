# frozen_string_literal: true
require_relative 'test_base'
require 'ostruct'

class HttpJsonResponderTest < TestBase

  def self.hex_prefix
    '375'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F0',
  'response.body is used when it has a key matching the path' do
    path = 'sha'
    json_body = { path => 42 }.to_json
    requester = HttpJsonRequesterStub.new(json_body)
    responder = HttpJson::Responder.new(requester, RunnerServiceErrorStub)
    response = responder.get(path, nil)
    assert_equal 42, response
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F1',
  'raises when response.body is not JSON' do
    assert_responder_raises('xxxx') do |error_message|
      assert_equal 'http response.body is not JSON:xxxx', error_message
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F2',
  'raises response.body is not JSON Hash' do
    assert_responder_raises('[]') do |error_message|
      assert_equal 'http response.body is not JSON Hash:[]', error_message
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F3',
  'raises when response.body has embedded exception' do
    json_body = { 'exception' => { 'message' => 'wibble' }}.to_json
    assert_responder_raises(json_body) do |error_message|
      json = JSON.parse(error_message)
      assert_equal 'wibble', json['message']
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F4',
  'raises when response.body has no key matching path' do
    json_body = { 'not_sha' => 'hello' }.to_json
    assert_responder_raises(json_body, 'sha') do |error_message|
      expected = "http response.body has no key for 'sha':{\"not_sha\":\"hello\"}"
      assert_equal expected, error_message
    end
  end

  private

  class HttpJsonRequesterStub
    def initialize(body)
      @body = body
    end
    def get(_path,_args)
      OpenStruct.new(body:@body)
    end
  end

  class RunnerServiceErrorStub < RuntimeError
    def initialize(message)
      super
    end
  end

  def assert_responder_raises(json_body, path=nil)
    requester = HttpJsonRequesterStub.new(json_body)
    responder = HttpJson::Responder.new(requester, RunnerServiceErrorStub)
    error = assert_raises(RunnerServiceErrorStub) {
      responder.get(path, nil)
    }
    yield error.message
  end

end
