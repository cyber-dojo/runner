require_relative 'test_base'
require_relative 'shell_mocker'
#require_relative '../../src/logger_spy'

class PullerTest < TestBase

  def self.hex_prefix; '0D5713'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # pulled?
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

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

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '934',
  'when image_name is invalid, image_pull() raises' do
    invalid_image_names.each do |image_name|
      error = assert_raises(StandardError) {
        image_pull image_name
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '91C',
  'when image_name is valid, image_pull() issues unconditional docker-pull' do
    mock_docker_pull_cdf_ruby_mini_test
    image_pull "#{cdf}/ruby_mini_test"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '933',
  'when there is no network connectivitity, image_pull() raises' do
    image_name = "#{cdf}/gcc_assert"
    cmd = "docker pull #{image_name}"
    stdout = [
      'Using default tag: latest',
      "Pulling repository docker.io/#{image_name}"
    ].join("\n")
    stderr = [
      'Error while pulling image: Get',
      "https://index.docker.io/v1/repositories/#{image_name}/images:",
      'dial tcp: lookup index.docker.io on 10.0.2.3:53: no such host'
    ].join(' ')
    shell.mock_exec(cmd, stdout, stderr, status=1)
    error = assert_raises { image_pull image_name }
    assert_equal "command:#{cmd}", error.message
  end

  private

  def mock_docker_images_prints_gcc_assert
    cmd = 'docker images --format "{{.Repository}}"'
    stdout = "#{cdf}/gcc_assert"
    shell.mock_exec(cmd, stdout, stderr='', shell.success)
  end

  def mock_docker_pull_cdf_ruby_mini_test
    image_name = "#{cdf}/ruby_mini_test"
    cmd = "docker pull #{image_name}"
    shell.mock_exec(cmd, stdout='', stderr='', shell.success)
  end

  def cdf
    'cyberdojofoundation'
  end

  def invalid_image_names
    [
      '',             # nothing!
      '_',            # cannot start with separator
      'name_',        # cannot end with separator
      'ALPHA/name',   # no uppercase
      'alpha/name_',  # cannot end in separator
      'alpha/_name',  # cannot begin with separator
    ]
  end

end

