# frozen_string_literal: true
require_relative '../test_base'

class BinaryFileTest < TestBase

  def self.id58_prefix
    'd93'
  end

  # - - - - - - - - - - - - - - - - -

  test '52A', %w(
  an incoming file with rogue characters
  is seen as a binary file
  so is not harvested from the container
  so becomes a deleted file
  ) do
    set_context
    filename = 'target.not.txt'
    unclean_str = (100..1000).to_a.pack('c*').force_encoding('utf-8')
    files = starting_files
    files[filename] = unclean_str
    command = "file --mime-encoding #{filename}"
    files['cyber-dojo.sh'] = command

    puller.add(image_name)
    manifest['max_seconds'] = 3

    run_result = runner.run_cyber_dojo_sh(
      id:id,
      files:files,
      manifest:manifest
    )

    assert_equal "#{filename}: binary\n", run_result['stdout']['content']

    assert_equal([filename], run_result['deleted'], :deleted)
  end

end
