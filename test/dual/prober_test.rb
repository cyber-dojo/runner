require_relative '../test_base'

module Dual
  class ProberTest < TestBase
    def self.id58_prefix
      '6de'
    end

    # - - - - - - - - - - - - - - - - -

    test '190', %w[
      alive? is true
    ] do
      set_context
      assert prober.alive?.is_a?(TrueClass)
    end

    # - - - - - - - - - - - - - - - - -

    test '191', %w[
      ready? is true
    ] do
      set_context
      assert prober.ready?.is_a?(TrueClass)
    end

    # - - - - - - - - - - - - - - - - -

    #     test '192', %w(
    #     sha is SHA of git commit which created docker image
    #     ) do
    #       set_context
    #       assert_sha(prober.sha)
    #     end
  end
end
