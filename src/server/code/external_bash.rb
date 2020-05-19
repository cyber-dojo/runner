# frozen_string_literal: true
require 'open3'

class ExternalBash

  def exec(command)
    stdout,stderr,r = Open3.capture3(command)
    [ stdout, stderr, r.exitstatus ]
  end

  def teardown
  end

end
