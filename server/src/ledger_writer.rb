
class LedgerWriter # MethodLog ?

  def initialize
    @hash = {}
  end

  def write(key, message)
    @hash[key] = message
  end

  def key?(key)
    @hash.key?(key)
  end

  def [](key)
    @hash[key]
  end

end
