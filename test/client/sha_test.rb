# frozen_string_literal: true
require_relative 'test_base'

class ShaTest < TestBase

  def self.id58_prefix
    '1B6'
  end

  # - - - - - - - - - - - - - - - - -

  test '882', 'sha' do
    sha = runner.sha['sha']
    assert git_sha?(sha), sha
  end

  private

  def git_sha?(s)
    s.is_a?(String) &&
      s.size === 40 &&
        s.each_char.all?{ |ch| is_lo_hex?(ch) }
  end

  def is_lo_hex?(ch)
    '0123456789abcdef'.include?(ch)
  end

end
