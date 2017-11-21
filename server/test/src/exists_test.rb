require_relative 'test_base'

class ExistsTest < TestBase

  def self.hex_prefix
    '98F99'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4D2',
  %w( kata and avatar exist inside container ) do
    runner = Runner.new(self, image_name, kata_id)
    runner.kata_new
    runner.avatar_new('lion', starting_files)
    runner.send(:in_container) {
      assert runner.kata_exists?
      assert runner.avatar_exists?('lion')
    }
    runner.avatar_old('lion')
    runner.kata_old
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4D3',
  %w( kata and avatar do not exist outside container ) do
    runner = Runner.new(self, image_name, kata_id)
    runner.kata_new
    runner.avatar_new('rhino', starting_files)
    refute runner.kata_exists?
    refute runner.avatar_exists?('rhino')
    runner.avatar_old('rhino')
    runner.kata_old
  end

end
