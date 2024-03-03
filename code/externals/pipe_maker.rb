# frozen_string_literal: true
require 'ostruct'

class PipeMaker
  def make
    Pipe.new(*IO.pipe)
  end

  Pipe = Struct.new(:in, :out)
end
