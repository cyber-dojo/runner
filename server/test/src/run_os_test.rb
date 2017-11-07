require_relative 'test_base'
require_relative 'os_helper'

class RunOSTest < TestBase

  include OsHelper

  def self.hex_prefix
    '3759D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.os_test(hex_suffix, *lines, &test_block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &test_block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &test_block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'C3A',
  'invalid avatar_name raises' do
    in_kata { invalid_avatar_name_raises }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '8A3',
  'run is initially red' do
    in_kata_as(salmon) { run_is_initially_red }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'A88',
  'container has init process running on pid 1' do
    in_kata_as(salmon) { pid_1_init_process_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '997',
  'container has access to cyber-dojo env-vars' do
    in_kata_as(lion) { kata_id_env_vars_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '267',
  'all of the 64 avatar users already exist in the image' do
    in_kata_as(squid) { assert_avatar_users_exist }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '582',
  'the cyber_dojo group already exists in the image' do
    in_kata_as(salmon) { assert_cyber_dojo_group_exists }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '2A0',
  'avatar_new has HOME set off /home' do
    in_kata_as(lion) { avatar_new_home_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '0C9',
  'avatar_new has its own sandbox with owner/group/permissions set' do
    in_kata_as(squid) { avatar_new_sandbox_setup_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '1FB',
  'avatar_new has starting-files in its sandbox with owner/group/permissions set' do
    in_kata_as(salmon) { avatar_new_starting_files_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'D7C',
  'the container is ulimited' do
    in_kata_as(lion) { ulimit_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'FEA',
  'test-event baseline speed' do
    in_kata_as(squid) { baseline_speed_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B81',
  'files can be in sub-dirs of sandbox' do
    in_kata_as(salmon) { files_can_be_in_sub_dirs_of_sandbox }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B84',
  'files can be in sub-sub-dirs of sandbox' do
    in_kata_as(lion) { files_can_be_in_sub_sub_dirs_of_sandbox }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B6E',
  'files have time-stamp with microseconds granularity' do
    in_kata_as(squid) { files_have_time_stamp_with_microseconds_granularity }
  end

end
