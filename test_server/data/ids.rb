
module Test
  module Data

    MALFORMED_IDS =
      [
        nil,          # not String
        Object.new,   # not String
        [],           # not String
        '',           # not 6 chars
        '12345',      # not 6 chars
        '1234567',    # not 6 chars
      ]

  end
end
