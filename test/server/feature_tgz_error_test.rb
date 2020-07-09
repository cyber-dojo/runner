# frozen_string_literal: true
require_relative 'test_base'

class FeatureTgzErrorTest < TestBase

  def self.id58_prefix
    '0fK'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'q8E', %w(
  faulty untgz
  is logged
  and typically results in amber traffic-light ) do
    # override logger (already set in TestBase c'tor)
    @context = Context.new(
      threader:ThreaderStub.new,
      logger:StdoutLoggerSpy.new
    )
    @context.puller.add(image_name)
    run_cyber_dojo_sh
    assert logged?('Zlib::GzipFile::Error'), pretty_result(:log)
    assert_equal 'amber', colour, pretty_result(:colour)
  end

  private

  class ThreaderStub
    def thread(&_block)
      self
    end
    def value
      'not-a-tgz-stream'
    end
  end

end
