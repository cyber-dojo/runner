require_relative '../test_base'
require_relative '../data/image_names'
require_code 'docker_image_name'

class DockerImageNameTest < TestBase

  test '9g8000', 'malformed_image_name' do
    Test::Data::ImageNames::MALFORMED.each do |image_name|
      refute DockerImageName.valid?(image_name), image_name
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8001', %w[unchanged when a tag and no digest] do
    Test::Data::ImageNames::TAG_YES_DIGEST_NO.each do |image_name|
      assert DockerImageName.valid?(image_name), image_name
      expected = image_name
      actual = DockerImageName.tagged(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8002', %w[unchanged when a tag and a digest] do
    Test::Data::ImageNames::TAG_YES_DIGEST_YES.each do |image_name|
      assert DockerImageName.valid?(image_name), image_name
      expected = image_name
      actual = DockerImageName.tagged(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8003', %w[tagged with :latest when no tag and no digest] do
    Test::Data::ImageNames::TAG_NO_DIGEST_NO.each do |image_name|
      assert DockerImageName.valid?(image_name), image_name
      expected = "#{image_name}:latest"
      actual = DockerImageName.tagged(image_name)
      assert_equal expected, actual
    end
  end

  # - - - - - - - - - - - - - - - - -

  # A digest carries a colon, and a registry can carry a :port, so the tag is
  # not simply what follows the last colon. These pin every shape they make.
  DIGEST = '@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'.freeze

  test '9g8005', %w[accepted when pinned to a tag that is not :latest,
                    and the tag read is the one written
                    rather than a digest's or a registry port's] do
    [
      'cyberdojofoundation/gcc_assert:1a2b3c4',
      "cyberdojofoundation/gcc_assert:1a2b3c4#{DIGEST}",
      'localhost:5000/gcc_assert:1a2b3c4',
      "localhost:5000/gcc_assert:1a2b3c4#{DIGEST}"
    ].each do |image_name|
      DockerImageName.assert_versioned(image_name)
      assert_equal '1a2b3c4', DockerImageName.tag_of(image_name), image_name
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8006', %w[rejected when it resolves to :latest,
                    whether :latest is said out loud, left unsaid,
                    or hidden behind a digest] do
    [
      'cyberdojofoundation/gcc_assert',
      'cyberdojofoundation/gcc_assert:latest',
      "cyberdojofoundation/gcc_assert#{DIGEST}",
      "cyberdojofoundation/gcc_assert:latest#{DIGEST}",
      'localhost:5000/gcc_assert',
      'localhost:5000/gcc_assert:latest',
      "localhost:5000/gcc_assert:latest#{DIGEST}"
    ].each do |image_name|
      assert_raises(DockerImageName::Unversioned, image_name) do
        DockerImageName.assert_versioned(image_name)
      end
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '9g8004', %w[tagged with :latest when no tag and a digest] do
    Test::Data::ImageNames::TAG_NO_DIGEST_YES.each do |image_name|
      assert DockerImageName.valid?(image_name), image_name
      at = image_name.index('@')
      lhs = image_name[0..at - 1]
      rhs = image_name[at..]
      expected = "#{lhs}:latest#{rhs}"
      actual = DockerImageName.tagged(image_name)
      assert_equal expected, actual
    end
  end
end
