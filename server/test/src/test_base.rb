require_relative '../hex_mini_test'
#require_relative '../../src/externals'
require_relative '../../src/runner'
require 'json'

class TestBase < HexMiniTest

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def runner
    @runner ||= Runner.new(self)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?(image_name)
    runner.image_pulled?(image_name)
  end

  def image_pull(image_name)
    runner.image_pull(image_name)
  end

end
