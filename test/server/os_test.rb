# frozen_string_literal: true
require_relative 'test_base'
require 'json'

class OsTest < TestBase

  def self.id58_prefix
    '669'
  end

  def id58_setup
    context.puller.add(image_name)
  end

  # - - - - - - - - - - - - - - - - -

  alpine_test '8A2', %w( os<-->image correspondence ) do
    assert_cat_etc_issue
  end

  debian_test '8A3', %w( os<-->image correspondence ) do
    assert_cat_etc_issue
  end

  ubuntu_test '8A4', %w( os<-->image correspondence ) do
    assert_cat_etc_issue
  end

  # - - - - - - - - - - - - - - - - -

  def assert_cat_etc_issue
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    diagnostic = [
      "image_name=:#{image_name}:",
      "did not find #{os} in etc/issue",
      etc_issue
    ].join("\n")
    assert etc_issue.include?(os.to_s), diagnostic
  end

end
