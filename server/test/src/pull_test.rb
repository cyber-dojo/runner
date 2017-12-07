require_relative 'test_base'
require_relative 'bash_stub'

class PullTest < TestBase

  def self.hex_prefix
    '0D571'
  end

  def hex_setup
    rack.bash = BashStub.new
  end

  def hex_teardown
    rack.bash.teardown
  end

  def set_image_name(image_name)
    @image_name = image_name
  end

  # - - - - - - - - - - - - - - - - - - - -
  # image_pulled?
  # - - - - - - - - - - - - - - - - - - - -

  test '9C3',
  'false when image_name is valid but not in [docker images]' do
    set_image_name 'cdf/ruby_mini_test:1.9.3'
    stub_docker_images_prints 'cdf/gcc_assert'
    refute image_pulled?
    assert_no_exception
  end

  # - - - - - - - - - - - - - - - - - - - -

  test '9C4',
  'true when image_name is valid and in [docker images]' do
    set_image_name 'cdf/gcc_assert'
    stub_docker_images_prints 'cdf/gcc_assert'
    assert image_pulled?
    assert_no_exception
  end

  # - - - - - - - - - - - - - - - - - - - -

  test '9C5',
  'raises when [docker images ...] fails' do
    cmd = 'docker images --format "{{.Repository}}"'
    rack.bash.stub_run(cmd, stdout='x', stderr='y', status=1)
    assert_nil image_pulled?
    assert_exception({
      command:cmd,
      stdout:stdout,
      stderr:stderr,
      status:status
    })
  end

  # - - - - - - - - - - - - - - - - - - - -
  # image_pull
  # - - - - - - - - - - - - - - - - - - - -

  test '91C',
  'true when image_name is valid and exists' do
    set_image_name 'cdf/ruby_mini_test'

    stub_docker_pull_success image_name, tag=''
    assert image_pull
    assert_no_exception

    stub_docker_pull_success image_name, tag='latest'
    assert image_pull
    assert_no_exception
  end

  # - - - - - - - - - - - - - - - - - - - -

  test 'D80',
  'false when image_name does not exist or no pull access' do
    set_image_name 'cdf/does_not_exist'
    command = "docker pull #{image_name}"
    stdout = 'Using default tag: latest'
    stderr = [
      'Error response from daemon: ',
      "repository #{image_name} not found: ",
      'does not exist or no pull access'
    ].join
    rack.bash.stub_run(command, stdout, stderr, status=1)

    refute image_pull
    assert_no_exception
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '933',
  'raises when there is no network connectivitity' do
    set_image_name 'cdf/gcc_assert'
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
    rack.bash.stub_run(command, stdout, stderr, status=1)

    assert_nil image_pull
    assert_exception({
      command:command,
      stdout:stdout,
      stderr:stderr,
      status:status
    })
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
    set_image_name image_name
    cmd = "docker pull #{image_name}"
    rack.bash.stub_run(cmd, stdout, stderr, status)
  end

  # - - - - - - - - - - - - - - - - - - - -

  def stub_docker_images_prints(image_name)
    cmd = 'docker images --format "{{.Repository}}"'
    rack.bash.stub_run(cmd, stdout=image_name, stderr='', status=0)
  end

end

