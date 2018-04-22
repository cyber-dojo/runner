
class LogRaiser

  def <<(_msg)
    raise self.class.name
  end

end

