#require_relative 'all_avatars_names'
#require_relative 'nearest_ancestors'
#require_relative 'logger_null'
#require_relative 'string_cleaner'
#require_relative 'string_truncater'
#require 'timeout'

class Runner

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent # For nearest_ancestors()

  def image_pulled?(image_name)
    assert_valid image_name
    #image_names.include?(image_name)
    42
  end

  # - - - - - - - - - - - - - - - - - -

  def image_pull(image_name)
    assert_valid image_name
    #assert_exec("docker pull #{image_name}")
    42
  end

  # - - - - - - - - - - - - - - - - - -

  def run(image_name, visible_files, max_seconds)
    { stdout:'stdout', stderr:'stderr', status:0 }
  end

  private

  def assert_valid image_name
    unless valid? image_name
      fail_image_name('invalid')
    end
  end

  def valid? image_name
    # http://stackoverflow.com/questions/37861791/
    #      how-are-docker-image-names-parsed
    # https://github.com/docker/docker/blob/master/image/spec/v1.1.md
    # Simplified, no hostname, no :tag
    alpha_numeric = '[a-z0-9]+'
    separator = '[_.-]+'
    component = "#{alpha_numeric}(#{separator}#{alpha_numeric})*"
    name = "#{component}(/#{component})*"
    image_name =~ /^#{name}$/o
  end

  def fail_image_name(message)
    fail bad_argument("image_name:#{message}")
  end

  def bad_argument(message)
    ArgumentError.new(message)
  end

end
