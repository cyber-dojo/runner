# frozen_string_literal: true
class Prober
  def initialize(_context); end

  def alive?
    true
  end

  def ready?
    true
  end

  def sha
    ENV.fetch('SHA', nil)
  end

  def base_image
    ENV.fetch('BASE_IMAGE', nil)
  end
end
