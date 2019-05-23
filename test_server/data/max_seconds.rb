
module Test
  module Data

    MALFORMED_MAX_SECONDS =
      [
        nil,         # not Integer
        Object.new,  # not Integer
        [],          # not Integer
        {},          # not Integer
        '',          # not Integer
        12.45,       # not Integer
        -1,          # not (1..20)
        0,           # not (1..20)
        21           # not (1..20)
      ]

  end
end
