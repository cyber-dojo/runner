require_relative 'test_base'
require_relative 'shell_mocker'

class PullTest < TestBase

  def self.hex_prefix
    '0D571'
  end

  def hex_setup
    @shell = ShellMocker.new(nil)
  end

  def hex_teardown
    shell.teardown
  end

  def set_image_name(image_name)
    @image_name = image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '9C3',
  'false when image_name is valid but not in [docker images]' do
    set_image_name 'cdf/ruby_mini_test:1.9.3'
    mock_docker_images_prints 'cdf/gcc_assert'
    refute image_pulled?
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'A44',
  'true when image_name is valid and in [docker images]' do
    set_image_name 'cdf/gcc_assert'
    mock_docker_images_prints 'cdf/gcc_assert'
    assert image_pulled?
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '91C',
  'true when image_name is valid and exists' do
    set_image_name 'cdf/ruby_mini_test'

    mock_docker_pull_success image_name, tag=''
    assert image_pull

    mock_docker_pull_success image_name, tag='latest'
    assert image_pull
  end

  def mock_docker_pull_success(image_name, tag)
    stdout = []
    if tag == ''
      stdout << 'Using default tag: latest'
    else
      image_name += ":#{tag}"
    end
    stdout << "latest: Pulling from #{image_name}"
    stdout << 'Digest: sha256:2abe11877faf57729d1d010a5ad95764b4d1965f3dc3e93cef2bb07bc9c5c07b'
    stdout << "Status: Image is up to date for #{image_name}:#{tag}"
    mock_docker_pull(image_name, stdout.join("\n"), stderr='', status=shell.success)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'D80',
  'false when image_name is valid but does not exist' do
    set_image_name 'cdf/does_not_exist'
    mock_docker_pull_not_exist image_name, tag=''
    refute image_pull
  end

  def mock_docker_pull_not_exist(repo, tag)
    stdout = (tag == '') ? 'Using default tag: latest' : ''
    stderr = [
      'Error response from daemon: ',
      "repository #{repo} not found: ",
      'does not exist or no pull access'
    ].join
    image_name = repo
    image_name += ":#{tag}" unless tag == ''
    mock_docker_pull(image_name, stdout, stderr, 1)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '933',
  'raises when there is no network connectivitity' do
    set_image_name 'cdf/gcc_assert'
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
    error = assert_raises(ArgumentError) { image_pull }
    assert_equal 'image_name:invalid', error.message
  end

  private

  def mock_docker_pull(image_name, stdout, stderr, status)
    set_image_name image_name
    cmd = "docker pull #{image_name}"
    shell.mock_exec(cmd, stdout, stderr, status)
  end

  def mock_docker_images_prints(image_name)
    cmd = 'docker images --format "{{.Repository}}"'
    shell.mock_exec(cmd, stdout=image_name, stderr='', shell.success)
  end

end

