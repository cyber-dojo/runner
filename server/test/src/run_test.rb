require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix
    '58410'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '27C',
  %w( valid image_names do not raise ) do
    valid_image_names.each do |image_name|
      set_image_name image_name
      runner
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '1DC',
  %w( invalid image_name raises ) do
    invalid_image_names.each do |invalid_image_name|
      set_image_name invalid_image_name
      error = assert_raises(ArgumentError) { sss_run }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3FF',
  %w( invalid kata_id raises ) do
    invalid_kata_ids.each do |invalid_kata_id|
      set_kata_id invalid_kata_id
      error = assert_raises(ArgumentError) { sss_run }
      assert_equal 'kata_id:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C3A',
  %w( invalid avatar_name raises ) do
    error = assert_raises(ArgumentError) {
      sss_run({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  %w( [Alpine] run initially red ) do
    sss_run
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8A4',
  %w( [Ubuntu] run initially red ) do
    sss_run
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B82',
  %w( files can be in sub-dirs of sandbox ) do
    sss_run({ visible_files: {
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
    sss_run({ visible_files: {
      'a/b/hello.txt'   => 'hello world',
      'cyber-dojo.sh'   => "cd a && #{ls_cmd}"
    }})
    ls_files = ls_parse(stdout)
    uid = runner.user_id('salmon')
    group = runner.group
    assert_equal_atts('b', 'drwxr-xr-x', uid, group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def valid_image_names
    [ "gcc_assert:#{'x'*127}" ] +
    %w(
      cdf/gcc_assert
      cdf/gcc_assert:latest
      quay.io/cdf/gcc_assert
      quay.io:8080/cdf/gcc_assert
      quay.io/cdf/gcc_assert:latest
      quay.io:8080/cdf/gcc_assert:12
      localhost/cdf/gcc_assert
      localhost/cdf/gcc_assert:tag
      localhost:80/cdf/gcc_assert
      localhost:80/cdf/gcc_assert:1.2.3
      gcc_assert
      gcc_assert:_
      gcc_assert:2
      gcc_assert:a
      gcc_assert:A
      gcc_assert:1.2
      gcc_assert:1-2
      cdf/gcc__assert:x
      cdf/gcc__sd.a--ssert:latest
      localhost/cdf/gcc_assert
      localhost:23/cdf/gcc_assert
      quay.io/cdf/gcc_assert
      quay.io:80/cdf/gcc_assert
      localhost/cdf/gcc_assert:latest
      localhost:23/cdf/gcc_assert:latest
      quay.io/cdf/gcc_assert:latest
      quay.io:80/cdf/gcc_assert:latest
      localhost/cdf/gcc__assert:x
      localhost:23/cdf/gcc__assert:x
      quay.io/cdf/gcc__assert:x
      quay.io:80/cdf/gcc__assert:x
      localhost/cdf/gcc__sd.a--ssert:latest
      localhost:23/cdf/gcc__sd.a--ssert:latest
      quay.io/cdf/gcc__sd.a--ssert:latest
      quay.io:80/cdf/gcc__sd.a--ssert:latest
      a-b-c:80/cdf/gcc__sd.a--ssert:latest
      a.b.c:80/cdf/gcc__sd.a--ssert:latest
      A.B.C:80/cdf/gcc__sd.a--ssert:latest
      gcc_assert@sha256:12345678901234567890123456789012
      gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      localhost/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      localhost:80/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      localhost:80/gcc_assert:tag@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      localhost:80/cdf/gcc_assert:tag@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      quay.io/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      quay.io:80/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      quay.io:80/gcc_assert:latest@sha2-s1+s2.s3_s5:12345678901234567890123456789012
      quay.io:80/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
      quay.io:80/cdf/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
      q.uay.io:80/cdf/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '67B',
  %w( When container cannot be removed a message is logged ) do
    @disk = DummyDiskSpy.new(nil)
    @shell = SimpleShellMocker.new(nil)
    @log = LoggerSpy.new(self)
    sss_run({ visible_files: {
      'cyber-dojo.sh' => ls_cmd,
      'a/hello.txt'   => 'hello world'
    }})
    expected = [ "Failed to confirm:remove_container(#{@shell.cid})" ]
    assert_equal expected, @log.spied
  end

end

# - - - - - - - - - - - - - - - - - - - - - - - - - -

class DummyDiskSpy
  def initialize(_)
  end
  def method_missing(_name, *_args, &_block)
  end
end

# - - - - - - - - - - - - - - - - - - - - - - - - - -

class SimpleShellMocker

  def initialize(_)
  end

  def assert_exec(command)
    stderr = ''
    if command.start_with? 'docker run'
      stdout = cid
    elsif command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
      stdout = red_amber_green
    else
      stdout = 'anything'
    end
    [ stdout, stderr ]
  end

  def exec(_command, _ = nil)
    stdout = 'stdout.anything'
    stderr = 'stderr.anything'
    status = 0
    [ stdout, stderr, status ]
  end

  def cid
    ENV['CYBER_DOJO_HEX_TEST_ID']
  end

  def red_amber_green
    'lambda { |stdout, stderr, status| :red }'
  end

end
