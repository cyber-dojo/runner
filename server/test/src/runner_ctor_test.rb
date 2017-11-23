require_relative 'test_base'
require_relative 'image_names'

class RunnerTest < TestBase

  def self.hex_prefix
    '4C8DB'
  end

  # - - - - - - - - - - - - - - - - -

  test 'D01',
  %w( runner with valid image_name and valid kata_id does not raise ) do
    valid_image_names.each do |image_name|
      Runner.new(self, image_name, kata_id)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'A53',
  %w( runner with invalid image_name raises ) do
    invalid_image_names.each do |invalid_image_name|
      error = assert_raises(ArgumentError) {
        Runner.new(self, invalid_image_name, kata_id)
      }
      assert_equal 'image_name:invalid', error.message
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '6FD',
  %w( runner with invalid kata_id raises ) do
    invalid_kata_ids.each do |invalid_kata_id|
      error = assert_raises(ArgumentError) {
        Runner.new(self, "#{cdf}/gcc_assert", invalid_kata_id)
      }
      assert_equal 'kata_id:invalid', error.message
    end
  end

  private

  include ImageNames

  def invalid_kata_ids
    [
      nil,          # not string
      Object.new,   # not string
      [],           # not string
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789G'  # not 10 hex-chars
    ]
  end

end
