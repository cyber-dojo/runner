# frozen_string_literal: true
require_relative 'test_base'

class FeatureClangSanitizeAddressTest < TestBase

  def self.id58_prefix
    'D28'
  end

  # - - - - - - - - - - - - - - - - -

  clang_assert_test '0BB',
  %w( clang sanitize address ) do
    diagnostic = 'AddressSanitizer: heap-use-after-free on address'
    run_cyber_dojo_sh
    refute stderr.include?(diagnostic), stderr
    run_cyber_dojo_sh( {
      changed:{ 'hiker.c' => leaks_memory }
    })
    assert stderr.include?(diagnostic), stderr
  end

  # - - - - - - - - - - - - - - - - -

  def leaks_memory
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
  end

end
