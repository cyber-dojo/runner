require_relative 'test_base'

class ApiTest < TestBase

  def self.hex_prefix
    '3759D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # start-files image_name<->os correctness
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A1',
  'os-image correspondence' do
    in_kata_as(salmon) {
      etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
      diagnostic = [
        "image_name=:#{image_name}:",
        "did not find #{os} in etc/issue",
        etc_issue
      ].join("\n")
      case os
      when :Alpine
        assert etc_issue.include?('Alpine'), diagnostic
      when :Ubuntu
        assert etc_issue.include?('Ubuntu'), diagnostic
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # robustness
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F0',
  'call to non existent method becomes exception' do
    assert_exception('does_not_exist', {}.to_json)
  end

  multi_os_test '2F1',
  'call to existing method with bad json becomes exception' do
    assert_exception('does_not_exist', '{x}')
  end

  multi_os_test '2F2',
  'call to existing method with missing argument becomes exception' do
    in_kata {
      args = { image_name:image_name, kata_id:kata_id }
      assert_exception('avatar_new', args.to_json)
    }
  end

  multi_os_test '2F3',
  'call to existing method with bad argument type becomes exception' do
    in_kata_as(salmon) {
      args = {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:avatar_name,
        new_files:2, # <=====
        deleted_files:{},
        unchanged_files:{},
        changed_files:{},
        max_seconds:2
      }
      assert_exception('run_cyber_dojo_sh', args.to_json)
    }
  end

  include HttpJsonService

  def hostname
    'runner-stateless'
  end

  def port
    4597
  end

  def assert_exception(method_name, jsoned_args)
    json = http(method_name, jsoned_args) { |uri|
      Net::HTTP::Post.new(uri)
    }
    refute_nil json['exception']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # invalid arguments
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  METHOD_NAMES = [ :kata_new, :kata_old,
                   :avatar_new, :avatar_old,
                   :run_cyber_dojo_sh ]

  MALFORMED_IMAGE_NAMES = [ nil, '_cantStartWithSeparator' ]

  multi_os_test 'D21',
  'all api methods raise when image_name is invalid' do
    in_kata_as(salmon) do
      METHOD_NAMES.each do |method_name|
        MALFORMED_IMAGE_NAMES.each do |image_name|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { image_name:image_name }
          end
          expected = "RunnerService:#{method_name}:image_name:malformed"
          assert_equal expected, error.message
        end
      end
    end
  end

  MALFORMED_KATA_IDS = [ nil, '675' ]

  multi_os_test '656',
  'all api methods raise when kata_id is invalid' do
    in_kata_as(salmon) do
      METHOD_NAMES.each do |method_name|
        MALFORMED_KATA_IDS.each do |kata_id|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { kata_id:kata_id }
          end
          expected = "RunnerService:#{method_name}:kata_id:malformed"
          assert_equal expected, error.message
        end
      end
    end
  end

  MALFORMED_AVATAR_NAMES = [ nil, 'sunglasses' ]

  multi_os_test 'C3A',
  'api methods raise when avatar_name is invalid' do
    in_kata_as(salmon) do
      [ :avatar_new, :avatar_old, :run_cyber_dojo_sh ].each do |method_name|
        MALFORMED_AVATAR_NAMES.each do |avatar_name|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { avatar_name:avatar_name }
          end
          expected = "RunnerService:#{method_name}:avatar_name:malformed"
          assert_equal expected, error.message
        end
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # red-amber-green
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  '[C,assert] run with initial 6*9 == 42 is red' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert red?, result

      run_cyber_dojo_sh({
        changed_files: {
          'hiker.c' => hiker_c.sub('6 * 9', '6 * 9sd')
        }
      })
      assert amber?, result

      run_cyber_dojo_sh({
        changed_files: {
          'hiker.c' => hiker_c.sub('6 * 9', '6 * 7')
        }
      })
      assert green?, result
    }
  end

  def hiker_c
    starting_files['hiker.c']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # timing out
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3DC',
  '[C,assert] run with infinite loop times out' do
    in_kata_as(salmon) {
      from = 'return 6 * 9'
      to = "    for (;;);\n    return 6 * 7;"
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => hiker_c.sub(from, to) },
          max_seconds: 3
      })
      assert timed_out?, result
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # large-files
  # docker-compose.yml need a tmpfs for this to pass
  #      tmpfs: /tmp
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DB',
  'run with very large file is red' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        new_files: { 'big_file' => 'X'*1023*500 }
      })
    }
    assert red?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'ED4',
  'stdout greater than 10K is truncated' do
    # [1] fold limit is 10000 so I do two smaller folds
    five_K_plus_1 = 5*1024+1
    command = [
      'cat /dev/urandom',
      "tr -dc 'a-zA-Z0-9'",
      "fold -w #{five_K_plus_1}", # [1]
      'head -n 1'
    ].join('|')
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: {
          'cyber-dojo.sh' => "seq 2 | xargs -I{} sh -c '#{command}'"
        }
      })
    }
    assert stdout.include? 'output truncated by cyber-dojo'
  end

end
