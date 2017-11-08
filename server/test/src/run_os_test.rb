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
    in_kata { assert_invalid_avatar_name_raises }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '8A3',
  'run is initially red' do
    in_kata_as(salmon) { assert_run_is_initially_red }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'A88',
  'container has init process running on pid 1' do
    in_kata_as(salmon) { assert_pid_1_is_running_init_process }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '997',
  'container has access to cyber-dojo env-vars' do
    in_kata_as(lion) { assert_env_vars_present }
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
    in_kata_as(lion) { assert_avatar_has_home }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '0C9',
  'avatar_new has its own sandbox with owner/group/permissions set' do
    in_kata_as(squid) { assert_avatar_sandbox_properties }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '1FB',
  'avatar_new has starting-files in its sandbox with owner/group/permissions set' do
    in_kata_as(salmon) { assert_starting_files_properties }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'D7C',
  'the container is ulimited' do
    in_kata_as(lion) { assert_ulimits }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'FEA',
  'test-event baseline speed' do
    in_kata_as(squid) { assert_baseline_speed_test }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B81',
  'files can be in sub-dirs of sandbox' do
    in_kata_as(salmon) { assert_files_can_be_in_sub_dirs_of_sandbox }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B84',
  'files can be in sub-sub-dirs of sandbox' do
    in_kata_as(lion) { assert_files_can_be_in_sub_sub_dirs_of_sandbox }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'B6E',
  'files have time-stamp with microseconds granularity' do
    in_kata_as(squid) { assert_time_stamp_microseconds_granularity }
  end

end
