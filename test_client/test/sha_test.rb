# frozen_string_literal: true
require_relative 'test_base'

class ShaTest < TestBase

  def self.hex_prefix
    '1B6'
  end

  # - - - - - - - - - - - - - - - - -

  test '882', 'sha' do
    sha = runner.sha['sha']
    assert sha.is_a?(String)
    assert_equal 40, sha.size
    sha.each_char do |ch|
      assert '0123456789abcdef'.include?(ch)
    end
  end

end
