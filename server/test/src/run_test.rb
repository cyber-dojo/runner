require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; '58410'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BD5', %w(
  valid image_name with hostname does not raise
  ) do
    %w(
      quay.io/cdf/gcc_assert
      quay.io:8080/cdf/gcc_assert
      quay.io/cdf/gcc_assert:latest
      quay.io:8080/cdf/gcc_assert:12
      localhost/cdf/gcc_assert
      localhost/cdf/gcc_assert:tag
      localhost:80/cdf/gcc_assert
      localhost:80/cdf/gcc_assert:1.2.3
    ).each { |image_name|
      runner.image_pulled? image_name
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E', %w( [Alpine]
  valid image_name,kata_id,avatar_name does not raise
  ) do
    sss_run({
      image_name:VALID_ALPINE_IMAGE_NAME,
         kata_id:VALID_KATA_ID,
     avatar_name:VALID_AVATAR_NAME
    })
  end

  test '8A4', %w( [Ubuntu]
  valid image_name,kata_id,avatar_name does not raise
  ) do
    sss_run({
      image_name:VALID_UBUNTU_IMAGE_NAME,
         kata_id:VALID_KATA_ID,
     avatar_name:VALID_AVATAR_NAME
    })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8A9', %w(
  run returns red-amber-green traffic-light colour
  ) do
    sss_run( { image_name:"#{cdf}/gcc_assert" })
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B82', %w(
    files can be in sub-dirs of sandbox
  ) do
    sss_run( { visible_files: {
      'cyber-dojo.sh' => ls_cmd,
      'a/hello.txt' => 'hello world'
    }})
    ls_files = ls_parse(stdout)
    salmon_uid = runner.user_id('salmon')
    assert_equal_atts('a', 'drwxr-xr-x', salmon_uid, runner.group, 4096, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '1DC', %w(
  invalid image_name raises
  ) do
    error = assert_raises(ArgumentError) {
      sss_run({ image_name:INVALID_IMAGE_NAME })
    }
    assert_equal 'image_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3FF', %w(
  invalid kata_id raises
  ) do
    error = assert_raises(ArgumentError) {
      sss_run({ kata_id:INVALID_KATA_ID })
    }
    assert_equal 'kata_id:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C3A', %w(
  invalid avatar_name raises
  ) do
    error = assert_raises(ArgumentError) {
      sss_run({ avatar_name:INVALID_AVATAR_NAME })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  VALID_ALPINE_IMAGE_NAME = 'cyberdojofoundation/gcc_assert'
  VALID_UBUNTU_IMAGE_NAME = 'cyberdojofoundation/clangpp_assert'
  VALID_KATA_ID = '2911DDFD16'
  VALID_AVATAR_NAME = 'salmon'

  INVALID_IMAGE_NAME  = '_cantStartWithSeparator'
  INVALID_KATA_ID     = '345'
  INVALID_AVATAR_NAME = 'polaroid'

end
