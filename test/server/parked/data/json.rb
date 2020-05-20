
module Test
  module Data

    NOT_JSON =
      [
        # JSON::ParserError: 757: unexpected token at '...'
        'sdf',
        'nil',
      ]

    JSON_NOT_HASH =
      [
        'null',    # nil
        'true',    # true
        '42',      # 42
        '[]',      # []
        '["sdf"]', # ["sdf"]
        '[null]',  # [nil]
        '[true]',  # [true]
        '[42]',    # [42]
      ]

  end
end
