require_relative 'test_base'
require_relative 'os_helper'

class RunAlpineTest < TestBase

  include OsHelper

  def self.hex_prefix; '3759D'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.os_test(hex_suffix, *lines, &test_block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &test_block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &test_block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '997',
  'container has access to cyber-dojo env-vars' do
    kata_id_env_vars_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '582',
  'has group used for dir/file ownership' do
    assert_group_exists
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '2A0',
  'new_avatar has HOME set off /home' do
    new_avatar_home_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '0C9',
  'new_avatar has its own sandbox with owner/group/permissions set' do
    new_avatar_sandbox_setup_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '1FB',
  'new_avatar has starting-files in its sandbox with owner/group/permissions set' do
    new_avatar_starting_files_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

=begin
  os_test '4E8',
  'unchanged files still exist and are unchanged' do
    unchanged_files_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '385',
  'deleted files are removed',
  'and all previous files are unchanged' do
    deleted_files_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '232',
  'new files are added with owner/group/permissions',
  'and all previous files are unchanged' do
    new_files_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '9A7',
  'a changed file is resaved and its size and time-stamp updates',
  'and all previous files are unchanged' do
    changed_file_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'D7C',
  'is ulimited' do
    ulimit_test
  end
=end

end
