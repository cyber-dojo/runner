require_relative 'test_base'

class RedAmberGreenTest < TestBase

  def self.hex_prefix
    'FAA'
  end

  # - - - - - - - - - - - - - - - - -

  test '3DA', '[C,assert] test that runs and fails' do
    expected_stdout = "makefile:14: recipe for target 'test.output' failed"
    expected_stderr = [
      "test: hiker.tests.c:6: life_the_universe_and_everything: Assertion `answer() == 42' failed.",
      'make: *** [test.output]'
    ].join("\n")
    expected_status = 2

    run_cyber_dojo_sh
    assert stdout.include?(expected_stdout), stdout
    assert stderr.include?(expected_stderr), stderr
    assert_equal expected_status, status
  end

  # - - - - - - - - - - - - - - - - -

  test '3DB', '[C,assert] test that has compile-time error' do
    expected_stdout = "makefile:17: recipe for target 'test' failed"
    expected_stderr = [
      'hiker.c:5:16: error: invalid suffix "sd" on integer constant',
      'hiker.c:6:1: error: control reaches end of non-void function [-Werror=return-type]',
      "cc1: all warnings being treated as errors",
      "make: *** [test] Error 1"
    ]
    expected_status = 2

    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => intact(hiker_c.sub('6 * 9', '6 * 9sd'))
      }
    })
    assert_equal expected_stdout+"\n", stdout
    expected_stderr.each do |line|
      assert stderr.include?(line), stderr
    end
    assert_equal expected_status, status
  end

  # - - - - - - - - - - - - - - - - -

  test '3DC', '[C,assert] test that runs and passes' do
    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => intact(hiker_c.sub('6 * 9', '6 * 7'))
      }
    })
    assert_equal '', stdout
    assert_equal '', stderr
    assert_equal 0, status
  end

end
