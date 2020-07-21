# frozen_string_literal: true
require_relative 'test_base'

class FeatureTrafficLightTest < TestBase

  def self.id58_prefix
    '7B7'
  end

  def id58_setup
    context.puller.add(image_name)
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DB', %w( red/amber/green traffic-light ) do
    run_cyber_dojo_sh
    assert red?, pretty_result(:red)

    syntax_error = starting_files[filename_6x9].sub('6 * 9', '6 * 9sdf')
    run_cyber_dojo_sh({changed:{filename_6x9 => syntax_error}})
    assert amber?, pretty_result(:amber)

    passing = starting_files[filename_6x9].sub('6 * 9', '6 * 7')
    run_cyber_dojo_sh({changed:{filename_6x9 => passing}})
    assert green?, pretty_result(:green)
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test 'p3W', %w( stdout is not being whitespace stripped ) do
    stdout = assert_sss('printf " hel\nlo "')
    assert_equal " hel\nlo ", stdout
    # When home_files.rb's ~/cyber_dojo_main.sh puts a head in the pipe...
    #   cd #{sandbox_dir}
    #   bash ./cyber-dojo.sh \
    #    1> >(head -c#{max_file_size+1} > "${TMP_DIR}/stdout") \
    #    2> >(head -c#{max_file_size+1} > "${TMP_DIR}/stderr")
    # Then this test fails and stdout contains only a single newline.
    # It seems a head in the pipe is leaving its buffer unflushed.
    # See https://eklitzke.org/stdout-buffering
  end

  private

  def filename_6x9
    starting_files.keys.find { |filename|
      starting_files[filename].include?('6 * 9')
    }
  end

end