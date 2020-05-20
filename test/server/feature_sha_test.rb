# frozen_string_literal: true
require_relative 'test_base'

class ShaTest < TestBase

  def self.id58_prefix
    'FB3'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w(
  sha of git commit which created docker image is available through API
  ) do
    assert_sha(sha)
  end

end
