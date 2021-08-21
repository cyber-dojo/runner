class Random

  def hex8
    base = 16
    size = 8
    rand(base**(size-1)..base**size).to_s(base)
  end

end
