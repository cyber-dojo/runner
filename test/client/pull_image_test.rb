require_relative 'test_base'

class PullImageTest < TestBase

  def self.id58_prefix
    '4f5'
  end

  # - - - - - - - - - - - - - - - - -

  test 'g5S', %w(
  pull_image() first returns 'pulling' and then 'pulled'
  ) do
    image_name = 'busybox'
    expected = { 'pull_image' => 'pulling' }
    assert_equal expected, runner.pull_image(id:id58,image_name:image_name)
    count = 0
    pulled = { 'pull_image' => 'pulled' }
    while runner.pull_image(id:id58,image_name:image_name) != pulled
      count += 1
      sleep 0.25
    end
    assert count >= 2
  end

end
