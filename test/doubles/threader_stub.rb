# frozen_string_literal: true
require_relative 'thread_stub'

class ThreaderStub
  def initialize(stdout_tgz, stderr)
    @stdout_tgz = stdout_tgz
    @stderr = stderr
    @n = 0
  end
  def thread
    @n += 1
    if @n === 1
      return ThreadStub.new(@stdout_tgz)
    end
    if @n === 2
      return ThreadStub.new(@stderr)
    end
  end
end
