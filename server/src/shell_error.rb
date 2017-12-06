
class ShellError < StandardError

  def initialize(message, args)
    super(message)
    @args = args
  end

  attr_reader :args

end