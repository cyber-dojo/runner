require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix
    '58410'
  end

  def hex_setup
    set_image_name "#{cdf}/gcc_assert"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C3A',
  %w( invalid avatar_name raises ) do
    error = assert_raises(ArgumentError) {
      run_cyber_dojo_sh({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  %w( [Alpine] run initially red ) do
    in_kata {
      as(salmon) {
        run_cyber_dojo_sh
        assert_colour 'red'
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8A4',
  %w( [Ubuntu] run initially red ) do
    in_kata {
      as(salmon) {
        run_cyber_dojo_sh
        assert_colour 'red'
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B82',
  %w( files can be in sub-dirs of sandbox ) do
    in_kata {
      as(lion) {
        run_cyber_dojo_sh({
              new_files: { 'a/hello.txt'   => 'hello world' },
          changed_files: { 'cyber-dojo.sh' => ls_cmd }
        })
      }
    }
    ls_files = ls_parse(stdout)
    uid = user_id(lion)
    assert_equal_atts('a', 'drwxr-xr-x', uid, group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B83',
  %w( files can be in sub-sub-dirs of sandbox ) do
    in_kata {
      as(salmon) {
        run_cyber_dojo_sh({
          changed_files: { 'cyber-dojo.sh' => "cd a && #{ls_cmd}" },
              new_files: { 'a/b/hello.txt' => 'hello world' }
        })
      }
    }
    ls_files = ls_parse(stdout)
    uid = user_id(salmon)
    assert_equal_atts('b', 'drwxr-xr-x', uid, group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B6F',
  %w( [Alpine] start-files have time-stamp with microseconds granularity ) do
    # On _default_ Alpine date-time file-stamps are to the second granularity.
    # In other words, the microseconds value is always '000000000'.
    # Make sure the Alpine packages have been installed to fix this.
    in_kata {
      as(squid) {
        run_cyber_dojo_sh({
          changed_files: { 'cyber-dojo.sh' => ls_cmd },
              new_files: ls_starting_files
        })
      }
    }
    ls_parse(stdout).each do |filename,atts|
      refute_nil atts, filename
      stamp = atts[:time_stamp] # eg '07:03:14.835233538'
      microsecs = stamp.split((/[\:\.]/))[-1]
      assert_equal 9, microsecs.length
      refute_equal '0'*9, microsecs
    end
  end

end
