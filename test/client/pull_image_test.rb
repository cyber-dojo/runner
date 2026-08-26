require_relative '../test_base'

class PullImageTest < TestBase

  test '4f5g5S', %w(
  | pull_image('busybox:glibc') returns 'pulling',
  | then a short while later it returns 'pulled'
  ) do
    set_context
    # 'pulling' depends on busybox:glibc being absent, which
    # bin/setup_dependent_images.sh sees to before every run. That removal is
    # the daemon's whole image store rather than this compose project's, so a
    # second suite running alongside this one (COMPOSE_PROJECT_NAME overridden)
    # shares it: whichever suite pulls first leaves the other one 'pulled'.
    assert_equal 'pulling', pull_image
    count = 0
    while pull_image != 'pulled' && count < 50
      count += 1
      sleep 0.1
    end
    assert count.positive?
  end

  private

  def pull_image
    runner.pull_image(id: id58, image_name: 'busybox:glibc')
  end
end
