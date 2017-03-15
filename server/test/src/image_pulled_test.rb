require_relative 'test_base'
require_relative 'shell_mocker'

class ImagePulledTest < TestBase

  def self.hex_prefix; '109807'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown; end

  test 'D97',
  'raises when image_name is invalid' do
    invalid_image_names.each do |image_name|
      error = assert_raises(StandardError) {
        image_pulled? image_name
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '9C3',
  'false when image_name is valid but not in [docker images]' do
    mock_docker_images_prints "#{cdf}/gcc_assert"
    refute image_pulled? "#{cdf}/ruby_mini_test"

    mock_docker_images_prints "#{cdf}/gcc_assert"
    refute image_pulled? "#{cdf}/ruby_mini_test:latest"

    mock_docker_images_prints "#{cdf}/gcc_assert"
    refute image_pulled? "#{cdf}/ruby_mini_test:1.9.3"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'A44',
  'true when image_name is valid and in [docker images]' do
    mock_docker_images_prints "#{cdf}/gcc_assert"
    assert image_pulled? "#{cdf}/gcc_assert"
  end

  private

  def mock_docker_images_prints(image_name)
    cmd = 'docker images --format "{{.Repository}}"'
    shell.mock_exec(cmd, stdout=image_name, stderr='', shell.success)
  end

end

