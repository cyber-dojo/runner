# frozen_string_literal: true

class Prober

  def initialize(_externals)
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
