require_relative '../test_base'

class ClangSanitizeAddressTest < TestBase

  clang_assert_test 'D280BB', %w(
  | clang sanitize address => no ulimit on data
  ) do
    set_context

    run_cyber_dojo_sh(
      traffic_light: TrafficLightStub.amber,
      changed: { 'hiker.c' =>
        <<~C_SOURCE
          #include "hiker.h"
          #include <stdlib.h>

          int answer(void)
          {
              int * p = (int *)malloc(64);
              p[0] = 6;
              free(p);
              return p[0] * 7;
          }
        C_SOURCE
      }
    )

    diagnostic = 'AddressSanitizer: heap-use-after-free on address'
    assert stderr.include?(diagnostic), stderr
  end
end
