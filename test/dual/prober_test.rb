require_relative '../test_base'

module Dual
  class ProberTest < TestBase

    test '6de190', %w[
      alive? is true
    ] do
      set_context
      assert prober.alive?.is_a?(TrueClass)
    end

    # - - - - - - - - - - - - - - - - -

    test '6de191', %w[
      ready? is true
    ] do
      set_context
      assert prober.ready?.is_a?(TrueClass)
    end
  end
end
