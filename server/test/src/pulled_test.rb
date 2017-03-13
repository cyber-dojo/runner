require_relative 'test_base'
require_relative 'shell_mocker'

class PulledTest < TestBase

  def self.hex_prefix; '109807'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown; end

  test 'D97',
  'when image_name is invalid, image_pulled?() raises' do
    invalid_image_names.each do |image_name|
      error = assert_raises(StandardError) {
        image_pulled? image_name
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '9C3',
  'when image_name is valid but not in [docker images], image_pulled?() is false' do
    mock_docker_images_prints_gcc_assert
    refute image_pulled? "#{cdf}/ruby_mini_test"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'A44',
  'when image_name is valid and in [docker images], image_pulled?() is true' do
    mock_docker_images_prints_gcc_assert
    assert image_pulled? "#{cdf}/gcc_assert"
  end

  private

  def mock_docker_images_prints_gcc_assert
    cmd = 'docker images --format "{{.Repository}}"'
    stdout = "#{cdf}/gcc_assert"
    shell.mock_exec(cmd, stdout, stderr='', shell.success)
  end

end

