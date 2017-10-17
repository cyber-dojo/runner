require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix
    '58410'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C3A',
  %w( invalid avatar_name raises ) do
    error = assert_raises(ArgumentError) {
      run4({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  %w( [Alpine] run initially red ) do
    run4
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8A4',
  %w( [Ubuntu] run initially red ) do
    run4
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B82',
  %w( files can be in sub-dirs of sandbox ) do
    run4({ visible_files: {
      'a/hello.txt'   => 'hello world',
      'cyber-dojo.sh' => ls_cmd
    }})
    ls_files = ls_parse(stdout)
    uid = runner.user_id('salmon')
    group = runner.group
    assert_equal_atts('a', 'drwxr-xr-x', uid, group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B83',
  %w( files can be in sub-sub-dirs of sandbox ) do
    run4({ visible_files: {
      'a/b/hello.txt'   => 'hello world',
      'cyber-dojo.sh'   => "cd a && #{ls_cmd}"
    }})
    ls_files = ls_parse(stdout)
    uid = runner.user_id('salmon')
    group = runner.group
    assert_equal_atts('b', 'drwxr-xr-x', uid, group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B6F',
  %w( [Alpine] start-files have time-stamp with microseconds value of zero ) do
    # This is an affect of the tar-pipe
    run4({ visible_files:ls_starting_files })
    ls_parse(stdout).each do |filename,atts|
      refute_nil atts, filename
      stamp = atts[:time_stamp] # eg '07:03:14.000000000'
      microsecs = stamp.split(':')[-1].split('.')[-1]
      assert_equal '0'*9, microsecs
    end
  end

end
