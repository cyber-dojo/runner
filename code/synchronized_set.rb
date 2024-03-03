require 'set'

class SynchronizedSet
  def initialize
    @values = Set.new
    @mutex = Mutex.new
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

  def to_a
    @mutex.synchronize { @values.to_a.sort }
  end

  def delete(value)
    @mutex.synchronize { @values.delete(value) }
  end
end
