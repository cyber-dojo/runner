require 'ostruct'

class PipeMaker
  def initialize; end

  def make
    Pipe.new(*IO.pipe)
  end

  Pipe = Struct.new(:in, :out)
end
