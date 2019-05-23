module Test
  module Data

    MALFORMED_FILES =
      [
        nil,           # not Hash
        Object.new,    # not Hash
        [],            # not Hash
        '',            # not Hash
        'waterbottle', # not Hash
        { 'x' => [] }, # file is not Hash
        { 'y' => {}},  # file has no content
        { 'z' => { 'content' => 42 }} # file content !String
      ]

  end
end
