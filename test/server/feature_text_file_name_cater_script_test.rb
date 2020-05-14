# frozen_string_literal: true
require_relative 'test_base'

class TextFilenameCaterScriptTest < TestBase

  def self.id58_prefix
    'AA2'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '648', %w(
  new cater script exists
  ) do
    assert_cyber_dojo_sh('ls -al /tmp')
    assert stdout.include?('echo_truncated_textfilenames.sh')
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '649', %w(
  new cater script prints existing text filenames in /sandbox when sourced
  ) do
    assert_cyber_dojo_sh('source /tmp/echo_truncated_textfilenames.sh')
    assert stdout.include?('cyber-dojo.sh'), stdout
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '650', %w(
  new cater script prints created text filenames in /sandbox when sources
  ) do
    script = [
      'printf "xxx" > newfile.txt',
      'source /tmp/echo_truncated_textfilenames.sh'
    ].join(';')
    assert_cyber_dojo_sh(script)
    assert stdout.include?('newfile.txt'), stdout
  end

end
