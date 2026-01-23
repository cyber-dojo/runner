# frozen_string_literal: true
require_relative '../test_base'
require_relative '../data/image_names'
require_code 'tagged_image_name'

class TaggedImageNameTest < TestBase

  test '9g8000', 'malformed_image_name' do
    Test::Data::ImageNames::MALFORMED.each do |image_name|
      refute Docker.image_name?(image_name), image_name
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8001', %w[unchanged when a tag and no digest] do
    Test::Data::ImageNames::TAG_YES_DIGEST_NO.each do |image_name|
      assert Docker.image_name?(image_name), image_name
      expected = image_name
      actual = Docker.tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8002', %w[unchanged when a tag and a digest] do
    Test::Data::ImageNames::TAG_YES_DIGEST_YES.each do |image_name|
      assert Docker.image_name?(image_name), image_name
      expected = image_name
      actual = Docker.tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8003', %w[tagged with :latest when no tag and no digest] do
    Test::Data::ImageNames::TAG_NO_DIGEST_NO.each do |image_name|
      assert Docker.image_name?(image_name), image_name
      expected = "#{image_name}:latest"
      actual = Docker.tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8004', %w[tagged with :latest when no tag and a digest] do
    Test::Data::ImageNames::TAG_NO_DIGEST_YES.each do |image_name|
      assert Docker.image_name?(image_name), image_name
      at = image_name.index('@')
      lhs = image_name[0..at - 1]
      rhs = image_name[at..]
      expected = "#{lhs}:latest#{rhs}"
      actual = Docker.tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end
end
