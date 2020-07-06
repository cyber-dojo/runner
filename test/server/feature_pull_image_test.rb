# frozen_string_literal: true
require_relative 'test_base'
require_source 'puller'

class FeaturePullImageTest < TestBase

  def self.id58_prefix
    '9j5'
  end

  # - - - - - - - - - - - - - - - - -

  test 't9K', %w(
  pull an already added image_name returns :pulled
  ) do
    puller.add(gcc_assert)
    assert_equal :pulled, puller.pull_image(id:id, image_name:gcc_assert)
  end

  # - - - - - - - - - - - - - - - - -



  private

  def gcc_assert
    'cyberdojofoundation/gcc_assert:93eefc6'
  end

  def puller
    context.puller
  end

end
