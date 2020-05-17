# frozen_string_literal: true

module RandomHex

  def self.id(size)
    rand(16**(size-1)..16**size).to_s(16)
  end

  HEX_DIGITS = [*('a'..'z'),*('A'..'Z'),*('0'..'9')]

end
