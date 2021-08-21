class Prober

  def initialize(_context)
  end

  def alive?
    true
  end

  def ready?
    true
  end

  def sha
    ENV['SHA']
  end

end
