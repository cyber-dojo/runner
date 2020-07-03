# frozen_string_literal: true
require_relative 'test_base'
require_source 'tagged_image_name'
require_relative 'data/image_names'

class TaggedImageNameTest < TestBase

  def self.id58_prefix
    '9g8'
  end

  # - - - - - - - - - - - - - - - - -

  test '000', 'malformed_image_name' do
    Test::Data::ImageNames::MALFORMED.each do |image_name|
      refute Docker::image_name?(image_name), image_name
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '001', %w( unchanged when a tag and no digest ) do
    Test::Data::ImageNames::TAG_YES_DIGEST_NO.each do |image_name|
      assert Docker::image_name?(image_name), image_name
      expected = image_name
      actual = Docker::tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '002', %w( unchanged when a tag and a digest ) do
    Test::Data::ImageNames::TAG_YES_DIGEST_YES.each do |image_name|
      assert Docker::image_name?(image_name), image_name
      expected = image_name
      actual = Docker::tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '003', %w( tagged with :latest when no tag and no digest ) do
    Test::Data::ImageNames::TAG_NO_DIGEST_NO.each do |image_name|
      assert Docker::image_name?(image_name), image_name
      expected = image_name+':latest'
      actual = Docker::tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '004', %w( tagged with :latest when no tag and a digest ) do
    Test::Data::ImageNames::TAG_NO_DIGEST_YES.each do |image_name|
      assert Docker::image_name?(image_name), image_name
      at = image_name.index('@')
      lhs,rhs = image_name[0..at-1], image_name[at..-1]
      expected = "#{lhs}:latest#{rhs}"
      actual = Docker::tagged_image_name(image_name)
      assert_equal expected, actual
    end
  end

end
