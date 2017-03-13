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
    #assert_valid_image_name
    #image_names.include?(image_name)
    42
  end

  # - - - - - - - - - - - - - - - - - -

  def image_pull(image_name)
    #assert_valid_image_name
    #assert_exec("docker pull #{image_name}")
    42
  end

  # - - - - - - - - - - - - - - - - - -

  def run(image_name, visible_files, max_seconds)
    { stdout:'stdout', stderr:'stderr', status:0 }
  end

end
