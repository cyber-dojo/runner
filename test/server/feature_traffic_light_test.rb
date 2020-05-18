# frozen_string_literal: true
require_relative 'test_base'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.id58_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test 'p3W', %w( stdout is not being whitespace stripped ) do
    stdout = assert_cyber_dojo_sh('printf " hel\nlo "')
    assert_equal " hel\nlo ", stdout
    # NB: A trailing newline _is_ being stripped
  end

  # - - - - - - - - - - - - - - - - -

  test 'Hd7', %w( return colour in outermost JSON till clients upgrade ) do
    run_cyber_dojo_sh
    assert_equal 'red', result['colour'], JSON.pretty_generate(result)
    assert_equal 'red', result['run_cyber_dojo_sh'][:colour], JSON.pretty_generate(result)
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DB', %w( red traffic-light, no diagnostics ) do
    run_cyber_dojo_sh
    assert_equal 'red', colour, JSON.pretty_generate(result)
    assert log.empty?, :log_empty
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DC', %w( amber traffic-light, no diagnostics ) do
    syntax_error = starting_files[filename_6x9].sub('6 * 9', '6 * 9sdf')
    run_cyber_dojo_sh({changed:{filename_6x9=>syntax_error}})
    assert_equal 'amber', colour, JSON.pretty_generate(result)
    assert log.empty?, :log_empty
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DD', %w( green traffic-light, no diagnostics ) do
    passing = starting_files[filename_6x9].sub('6 * 9', '6 * 7')
    run_cyber_dojo_sh({changed:{filename_6x9=>passing}})
    assert_equal 'green', colour, JSON.pretty_generate(result)
    assert log.empty?, :log_empty
  end

  private

  def filename_6x9
    starting_files.keys.find { |filename|
      starting_files[filename].include?('6 * 9')
    }
  end

end
