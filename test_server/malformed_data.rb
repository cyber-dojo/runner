
module MalformedData

  def malformed_ids
    [
      nil,          # not String
      Object.new,   # not String
      [],           # not String
      '',           # not 6 chars
      '12345',      # not 6 chars
      '1234567',    # not 6 chars
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def malformed_files
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

  # - - - - - - - - - - - - - - - - -

  def malformed_max_seconds
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
