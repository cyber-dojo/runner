
class RunnerError < StandardError

  def initialize(info)
    @info = info
  end

  attr_reader :info

end