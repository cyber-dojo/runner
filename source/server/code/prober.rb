# frozen_string_literal: true

class Prober

  def initialize(_externals)
  end

  def alive?(args=nil)
    { 'alive?' => true }
  end

  def ready?(args=nil)
    { 'ready?' => true }
  end

  def sha(args=nil)
    { 'sha' => ENV['SHA'] }
  end

end
