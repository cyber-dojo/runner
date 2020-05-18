# frozen_string_literal: true

class Prober

  def initialize(_externals, _args)
  end

  def alive?
    { 'alive?' => true }
  end

  def ready?
    { 'ready?' => true }
  end

  def sha
    { 'sha' => ENV['SHA'] }
  end

end
