
module Test
  module Data

    WELL_FORMED_IMAGE_NAMES =
      [ "gcc_assert:#{'x'*127}" ] +
      %w(
        cdf/gcc_assert
        cdf/gcc_assert:latest
        quay.io/cdf/gcc_assert
        quay.io:8080/cdf/gcc_assert
        quay.io/cdf/gcc_assert:latest
        quay.io:8080/cdf/gcc_assert:12
        localhost/cdf/gcc_assert
        localhost/cdf/gcc_assert:tag
        localhost:80/cdf/gcc_assert
        localhost:80/cdf/gcc_assert:1.2.3
        gcc_assert
        gcc_assert:_
        gcc_assert:2
        gcc_assert:a
        gcc_assert:A
        gcc_assert:1.2
        gcc_assert:1-2
        cdf/gcc__assert:x
        cdf/gcc__sd.a--ssert:latest
        localhost/cdf/gcc_assert
        localhost:23/cdf/gcc_assert
        quay.io/cdf/gcc_assert
        quay.io:80/cdf/gcc_assert
        localhost/cdf/gcc_assert:latest
        localhost:23/cdf/gcc_assert:latest
        quay.io/cdf/gcc_assert:latest
        quay.io:80/cdf/gcc_assert:latest
        localhost/cdf/gcc__assert:x
        localhost:23/cdf/gcc__assert:x
        quay.io/cdf/gcc__assert:x
        quay.io:80/cdf/gcc__assert:x
        localhost/cdf/gcc__sd.a--ssert:latest
        localhost:23/cdf/gcc__sd.a--ssert:latest
        quay.io/cdf/gcc__sd.a--ssert:latest
        quay.io:80/cdf/gcc__sd.a--ssert:latest
        a-b-c:80/cdf/gcc__sd.a--ssert:latest
        a.b.c:80/cdf/gcc__sd.a--ssert:latest
        A.B.C:80/cdf/gcc__sd.a--ssert:latest
        gcc_assert@sha256:12345678901234567890123456789012
        gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        localhost/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        localhost:80/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        localhost:80/gcc_assert:tag@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        localhost:80/cdf/gcc_assert:tag@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        quay.io/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        quay.io:80/gcc_assert@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        quay.io:80/gcc_assert:latest@sha2-s1+s2.s3_s5:12345678901234567890123456789012
        quay.io:80/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
        quay.io:80/cdf/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
        q.uay.io:80/cdf/gcc_assert:latest@sha2-s1+s2.s3_s5:123456789012345678901234567890123456789
      )

    # - - - - - - - - - - - - - - - - - - - - - -

    HEX = 'D'

    MALFORMED_IMAGE_NAMES =
      [
        nil,
        '<none>',                 # [docker images] gives this
        '',                       # nothing!
        '_',                      # host-name cannot start with separator
        'name_',                  # host-name cannot end with separator
        ';;;',                    # host-name illegal char
        'ALPHA/name',             # no uppercase in host-name
        'gcc/Assert',             # no uppercase in remote-name
        'alpha/name_',            # remote-name cannot end in separator
        'alpha/_name',            # remote-name cannot begin with separator
        'gcc:.',                  # tag can't start with .
        'gcc:-',                  # tag can't start with -
        'gcc:{}',                 # {} is illegal tag
        "gcc:#{'x'*129}",         # tag too long
        '-/gcc/assert:23',        # - is illegal host-name
        '-x/gcc/assert:23',       # -x is illegal host-name
        'x-/gcc/assert:23',       # x- is illegal host-name
        '/gcc/assert',            # remote-name can't start with /
        "gcc@sha256:#{HEX*31}",   # digest-hex is too short
        "gcc!sha256-2:#{HEX*32}", # digest starts with @
        "gcc@256:#{HEX*32}",      # digest-component must start with letter
        "gcc@sha256-2:#{HEX*32}", # digest-component must start with letter
        "gcc@sha256#{HEX*32}",    # hex-digits starts with :
      ]

  end
end
