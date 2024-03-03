require_relative '../test_base'
require_code 'http_proxy/languages_start_points'
require_code 'http_proxy/runner'
require 'stringio'

class BadProxyCallTest < TestBase
  def self.id58_prefix
    '14D'
  end

  # - - - - - - - - - - - - - - - - -

  test '2F5', %w[
    call to existing runner method
    with bad argument type
    becomes Runner::Error
  ] do
    set_context
    error = assert_raises(::HttpProxy::Runner::Error) do
      run_cyber_dojo_sh(max_seconds: 'xxx')
    end
    json = JSON.parse(error.message)
    assert_equal '/run_cyber_dojo_sh', json['path']
    assert_equal 'Runner', json['class']
  end

  # - - - - - - - - - - - - - - - - -

  test '2F6', %w[
    call to existing languages_start_points method
    with bad argument type
    becomes LanguagesStartPoints::Error
  ] do
    set_context
    lsp = ::HttpProxy::LanguagesStartPoints.new
    error = assert_raises(::HttpProxy::LanguagesStartPoints::Error) do
      lsp.manifest('xxx')
    end
    json = JSON.parse(error.message)
    assert_equal 'manifest', json['path']
    assert_equal 'ArgumentError', json['class']
  end
end
