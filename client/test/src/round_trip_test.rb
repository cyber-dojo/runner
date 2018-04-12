require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    '2D128'
  end

  # - - - - - - - - - - - - - - - - -

  test '160',
  %w( [Ubuntu] sent files are returned in json payload ready to round-trip ) do
    in_kata_as('salmon') { run_cyber_dojo_sh }
    assert_equal(starting_files, files)
  end

end
