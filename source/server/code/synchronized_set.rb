# frozen_string_literal: true
require 'set'

class SynchronizedSet

  def initialize(enum = [])
    @values = Set.new(enum)
    @mutex = Mutex.new
  end

  def size
    @mutex.synchronize { @values.size }
  end

  def include?(value)
    # Documentation for Concurrent::Set suggests it locks
    # after the include, on each access. This should be faster.
    @mutex.synchronize { @values.include?(value) }
  end

  def add(value)
    @mutex.synchronize { @values.add(value) }
  end

  def add?(value)
    @mutex.synchronize { @values.add?(value) }
  end

  def delete(value)
    @mutex.synchronize { @values.delete(value) }
  end

end
