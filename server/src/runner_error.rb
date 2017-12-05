
class RunnerError < StandardError

  def initialize(info)
    super(info)
    @info = info
  end

  attr_reader :info

end