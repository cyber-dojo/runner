require_relative 'test_base'
require_relative 'shell_mocker'

class ImagePullTest < TestBase

  def self.hex_prefix; '0D5713'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown; end

  test '934',
  'raises when image_name is invalid' do
    invalid_image_names.each do |image_name|
      error = assert_raises(StandardError) {
        image_pull image_name
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '91C',
  'docker-pulls when image_name is valid' do
    mock_docker_pull "#{cdf}/ruby_mini_test"
    assert image_pull "#{cdf}/ruby_mini_test"

    mock_docker_pull "#{cdf}/ruby_mini_test:latest"
    assert image_pull "#{cdf}/ruby_mini_test:latest"

    mock_docker_pull "#{cdf}/ruby_mini_test:1.9.3"
    assert image_pull "#{cdf}/ruby_mini_test:1.9.3"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '933',
  'raises when there is no network connectivitity' do
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

  def mock_docker_pull(image_name)
    cmd = "docker pull #{image_name}"
    shell.mock_exec(cmd, stdout='', stderr='', shell.success)
  end

end

