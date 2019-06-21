require_relative 'test_base'

class ClangSanitizeAddressTest < TestBase

  def self.hex_prefix
    'D28'
  end

  def hex_setup
    @json = nil
  end

  # - - - - - - - - - - - - - - - - -

  test '0BB',
  %w( [clang,assert] clang sanitize address ) do
    diagnostic = 'AddressSanitizer: heap-use-after-free on address'
    run_cyber_dojo_sh
    refute stderr.include?(diagnostic), @json
    run_cyber_dojo_sh( {
      changed:{ 'hiker.c' => leaks_memory }
    })
    assert stderr.include?(diagnostic), @json
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
