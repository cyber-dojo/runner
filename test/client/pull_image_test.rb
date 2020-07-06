require_relative 'test_base'

class PullImageTest < TestBase

  def self.id58_prefix
    '4f5'
  end

  # - - - - - - - - - - - - - - - - -

  test 'g5S', %w(
  pull_image() first returns 'pulling' and then 'pulled'
  and :latest tag is added if needed
  ) do
    image_name = 'busybox'
    pulling = { 'pull_image' => 'pulling' }
    assert_equal pulling, runner.pull_image(id:id58,image_name:image_name)
    count = 0
    pulled = { 'pull_image' => 'pulled' }
    while runner.pull_image(id:id58,image_name:image_name) != pulled
      count += 1
      sleep 0.25
    end
    assert count >= 2
    assert_equal pulled, runner.pull_image(id:id58,image_name:'busybox:latest')
  end

end
