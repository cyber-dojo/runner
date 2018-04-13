require_relative 'test_base'
require_relative 'bash_stub'

class PullTest < TestBase

  def self.hex_prefix
    '0D571'
  end

  def hex_setup
    @external = External.new
    @external.bash = BashStub.new
  end

  def hex_teardown
    @external.bash.teardown
  end

  # - - - - - - - - - - - - - - - - - - - -
  # image_pulled?
  # - - - - - - - - - - - - - - - - - - - -

  test '9C3',
  'false when image_name is valid but not in [docker images]' do
    stub_docker_images_prints('cdf/gcc_assert')
    runner = Runner.new(@external, 'cdf/ruby_mini_test:1.9.3', kata_id)
    refute runner.image_pulled?
  end

  # - - - - - - - - - - - - - - - - - - - -

  test '9C4',
  'true when image_name is valid and in [docker images]' do
    stub_docker_images_prints('cdf/gcc_assert')
    runner = Runner.new(@external, 'cdf/gcc_assert', kata_id)
    assert runner.image_pulled?
  end

  # - - - - - - - - - - - - - - - - - - - -

  test '9C5',
  'raises when [docker images ...] fails' do
    cmd = 'docker images --format "{{.Repository}}"'
    @external.bash.stub_run(cmd, stdout='x', stderr='wibble', status=1)
    runner = Runner.new(@external, 'cdf/gcc_assert', kata_id)
    error = assert_raises { runner.image_pulled? }
    assert_equal 'wibble', error.message
  end

  # - - - - - - - - - - - - - - - - - - - -
  # image_pull
  # - - - - - - - - - - - - - - - - - - - -

  test '91C',
  'true when image_name is valid and exists' do
    stub_docker_pull_success 'cdf/gcc_assert', tag=''
    runner = Runner.new(@external, 'cdf/gcc_assert', kata_id)
    assert runner.image_pull

    stub_docker_pull_success 'cdf/gcc_assert', tag='latest'
    runner = Runner.new(@external, 'cdf/gcc_assert:latest', kata_id)
    assert runner.image_pull
  end

  # - - - - - - - - - - - - - - - - - - - -

  test 'D80',
  'false when image_name does not exist or no pull access' do
    command = 'docker pull cdf/gcc_assert'
    stdout = 'Using default tag: latest'
    stderr = [
      'Error response from daemon: ',
      "repository cdf/gcc_assert not found: ",
      'does not exist or no pull access'
    ].join
    @external.bash.stub_run(command, stdout, stderr, status=1)

    runner = Runner.new(@external, 'cdf/gcc_assert', kata_id)
    refute runner.image_pull
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '933',
  'raises when there is no network connectivitity' do
    image_name = 'cdf/gcc_assert'
    command = "docker pull #{image_name}"
    stdout = [
      'Using default tag: latest',
      "Pulling repository docker.io/#{image_name}"
    ].join("\n")
    stderr = [
      'Error while pulling image: Get',
      "https://index.docker.io/v1/repositories/#{image_name}/images:",
      'dial tcp: lookup index.docker.io on 10.0.2.3:53: no such host'
    ].join(' ')
    @external.bash.stub_run(command, stdout, stderr, status=1)

    runner = Runner.new(@external, 'cdf/gcc_assert', kata_id)
    error = assert_raises { runner.image_pull }
    assert_equal stderr, error.message
  end

  private # = = = = = = = = = = = = = = = =

  def stub_docker_pull_success(image_name, tag)
    stdout = []
    if tag == ''
      stdout << 'Using default tag: latest'
    else
      image_name += ":#{tag}"
    end
    stdout << "latest: Pulling from #{image_name}"
    stdout << 'Digest: sha256:2abe11877faf57729d1d010a5ad95764b4d1965f3dc3e93cef2bb07bc9c5c07b'
    stdout << "Status: Image is up to date for #{image_name}:#{tag}"
    stub_docker_pull(image_name, stdout.join("\n"), stderr='', status=0)
  end

  # - - - - - - - - - - - - - - - - - - - -

  def stub_docker_pull(image_name, stdout, stderr, status)
    cmd = "docker pull #{image_name}"
    @external.bash.stub_run(cmd, stdout, stderr, status)
  end

  # - - - - - - - - - - - - - - - - - - - -

  def stub_docker_images_prints(image_name)
    cmd = 'docker images --format "{{.Repository}}"'
    @external.bash.stub_run(cmd, stdout=image_name, stderr='', status=0)
  end

end

