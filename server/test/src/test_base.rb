require_relative '../hex_mini_test'
require_relative '../../src/externals'
require_relative '../../src/runner'
require 'json'

class TestBase < HexMiniTest

  include Externals

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

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('','w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

end
