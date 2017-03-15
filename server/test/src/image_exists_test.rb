require_relative 'test_base'
require_relative 'shell_mocker'

class ImageExistsTest < TestBase

  def self.hex_prefix; '1BA677'; end

  def hex_setup; @shell ||= ShellMocker.new(nil); end
  def hex_teardown; shell.teardown if shell.respond_to? :teardown; end

  test 'EED',
  'raises when image_name is invalid' do
    invalid_image_names.each do |image_name|
      error = assert_raises(StandardError) {
        image_exists? image_name
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '514',
  'false when image_name is valid but does not exist on dockerhub' do
    @image_name = "#{cdf}/ruby_mini_test"
    mock_docker_search_prints "#{cdf}/gcc_assert"
    refute image_exists? @image_name

    @image_name = "#{cdf}/ruby_mini_test:latest"
    mock_docker_search_prints "#{cdf}/gcc_assert"
    refute image_exists? @image_name

    @image_name = "#{cdf}/ruby_mini_test:1.9.3"
    mock_docker_search_prints "#{cdf}/gcc_assert"
    refute image_exists? @image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8EA',
  'true when image_name is valid and exists on dockerhub' do
    @image_name = "#{cdf}/gcc_assert"
    mock_docker_search_prints @image_name
    assert image_exists? @image_name

    @image_name = "#{cdf}/gcc_assert:latest"
    mock_docker_search_prints @image_name
    assert image_exists? @image_name

    @image_name = "#{cdf}/gcc_assert:2.6"
    mock_docker_search_prints @image_name
    assert image_exists? @image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BD5',
  'non mocked calls which require internet access' do
    @shell = ShellBasher.new(self)

    error = assert_raises(StandardError) {
      image_exists? invalid_image_names[0]
    }
    assert_equal 'image_name:invalid', error.message

    assert image_exists? "#{cdf}/gcc_assert"

    refute image_exists? "#{cdf}/does_not_exist"
  end

  private

  def mock_docker_search_prints(found_image_name)
    cmd = "docker search #{@image_name}"
    stdout = [
      'NAME                               DESCRIPTION   STARS     OFFICIAL   AUTOMATED',
      "#{found_image_name}  0"
    ].join("\n")
    shell.mock_exec(cmd, stdout, stderr='', shell.success)
  end

end

