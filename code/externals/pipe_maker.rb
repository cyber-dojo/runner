# frozen_string_literal: true
require 'ostruct'

class PipeMaker

  def initialize
  end

  def make
    Pipe.new(*IO.pipe)
  end

  private

  Pipe = Struct.new(:in, :out)

end
