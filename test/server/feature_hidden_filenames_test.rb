# frozen_string_literal: true
require_relative 'test_base'

class FeatureHiddenFilenamesTest < TestBase

  def self.id58_prefix
    'h4G'
  end

  # - - - - - - - - - - - - - - - - -

  test 'c71', %w(
  when hidden_filenames is NOT in the manifest
  /sandbox changes are NOT returned
  ) do
    files = starting_files
    files['cyber-dojo.sh'] = 'printf "xxx" > newfile.txt'
    args = {
      'id' => id,
      'files' => files,
      'manifest' => {
        'image_name' => image_name,
        'max_seconds' => max_seconds
      }
    }
    options = { traffic_light:TrafficLightStub::red }
    @result = runner(args,options).run_cyber_dojo_sh
    assert_created({})
    assert_deleted([])
    assert_changed({})

  end

end
