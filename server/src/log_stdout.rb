
class LogStdout

  def <<(message)
    # prefer p to puts so we get inspect and not to_s
    p message
  end

end
