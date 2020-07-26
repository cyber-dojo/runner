# frozen_string_literal: true
require 'ostruct'

class Piper

  def initialize
  end

  def io
    Pipe.new(*IO.pipe)
  end

  private

  Pipe = Struct.new(:in, :out)

end
