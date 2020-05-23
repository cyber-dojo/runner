# frozen_string_literal: true
require_relative 'test_base'

class FeatureFileTruncationTest < TestBase

  def self.id58_prefix
    'E4A'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '52A',
  %w( generated text files bigger than 50K are truncated ) do
    filename = 'large_file.txt'
    script = "od -An -x /dev/urandom | head -c#{51*1024} > #{filename}"
    script += ';'
    script += "stat -c%s #{filename}"
    assert_sss(script)
    assert_equal "#{51*1024}\n", stdout, :stdout
    assert created[filename][:truncated], :truncated
    assert_equal 50*1024, created[filename][:content].size, :size
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '52B',
  %w( stdout and stderr are truncated to 50K ) do
    script = [
      "od -An -x /dev/urandom | head -c#{51*1024} > /tmp/stdout",
      "od -An -x /dev/urandom | head -c#{51*1024} > /tmp/stderr",
      "cat /tmp/stdout",
      "1>&2 cat /tmp/stderr"
    ].join(';')
    assert_sss(script)
    assert_equal 50*1024, run_result[:stdout][:content].size, :stdout_content_is_truncated
    assert run_result[:stdout][:truncated], :stdout_truncated_property_is_true
    assert_equal 50*1024, run_result[:stderr][:content].size, :stderr_content_is_truncated
    assert run_result[:stderr][:truncated], :stderr_truncated_property_is_true
  end

  # - - - - - - - - - - - - - - - - -

  test '52C',
  %w( source files bigger than 10K are not truncated ) do
    filename = 'Hiker.cs'
    src = starting_files[filename]
    large_comment = "/*#{'x'*10*1024}*/"
    refute_nil src
    run_cyber_dojo_sh(
      traffic_light:TrafficLightStub::amber,
      changed:{ filename => src + large_comment }
    )
    refute changed.keys.include?(filename)
  end

end
