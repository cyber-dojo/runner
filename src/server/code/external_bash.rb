# frozen_string_literal: true
require 'open3'

class ExternalBash

  def initialize(_externals)
  end

  def exec(command)
    stdout,stderr,r = Open3.capture3(command)
    [ stdout, stderr, r.exitstatus ]
  end

  def assert(command)
    stdout,stderr,r = Open3.capture3(command)
    [ stdout, stderr, r.exitstatus ]
  end

end
