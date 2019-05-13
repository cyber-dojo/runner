require_relative 'test_base'

class RedAmberGreenTest < TestBase

  def self.hex_prefix
    'FAA'
  end

  test '3DF',
  '[C,assert] run with initial 6*9 == 42 is red' do
    run_cyber_dojo_sh
    assert red?, result

    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => intact(hiker_c.sub('6 * 9', '6 * 9sd'))
      }
    })
    assert amber?, result

    run_cyber_dojo_sh({
      changed_files: {
        'hiker.c' => intact(hiker_c.sub('6 * 9', '6 * 7'))
      }
    })
    assert green?, result
  end

end
