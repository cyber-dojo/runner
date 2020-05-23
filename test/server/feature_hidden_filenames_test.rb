# frozen_string_literal: true
require_relative 'test_base'

class FeatureHiddenFilenamesTest < TestBase

  def self.id58_prefix
    'h4G'
  end

  # - - - - - - - - - - - - - - - - -

  test 'c71', %w(
  when hidden_filenames is NOT in the manifest
  /sandbox changes are NOT returned
  ) do
    hidden_filenames_run(nil, create_delete_change_script)
    assert_created({})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test 'c72', %w(
  when hidden_filenames is []
  /sandbox changes are all returned
  ) do
    hidden_filenames_run([], create_delete_change_script)
    assert_created({ created_filename => intact(created_content) })
    assert_deleted([ deleted_filename ])
    assert_changed({ changed_filename => intact(changed_content) })
  end

  # - - - - - - - - - - - - - - - - -


  private

  def create_delete_change_script
    [
      "printf #{created_content} > #{created_filename}",
      "rm #{deleted_filename}",
      "printf #{appended_content} >> #{changed_filename}"
    ].join(';')
  end

  def hidden_filenames_run(hf, script)
    args = {
      'id' => id,
      'files' => {
        'cyber-dojo.sh' => script,
        deleted_filename => 'any-content',
        changed_filename => original_content
      },
      'manifest' => {
        'image_name' => image_name,
        'max_seconds' => max_seconds,
        'hidden_filenames' => hf
      }
    }
    options = { traffic_light:TrafficLightStub::red }
    @result = runner(args,options).run_cyber_dojo_sh
  end

  def created_filename; 'created.txt'; end
  def created_content; 'abc'; end

  def deleted_filename; 'deleted.txt'; end

  def changed_filename; 'changed.txt'; end
  def original_content; 'def'; end
  def appended_content; 'ghi'; end
  def changed_content; original_content + appended_content; end

end
