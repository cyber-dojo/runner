require_relative 'test_base'
require_relative 'shell_mocker'

class PullerTest < TestBase

  def self.hex_prefix; '0D5713'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown; end

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

  def mock_docker_pull_cdf_ruby_mini_test
    image_name = "#{cdf}/ruby_mini_test"
    cmd = "docker pull #{image_name}"
    shell.mock_exec(cmd, stdout='', stderr='', shell.success)
  end

end

