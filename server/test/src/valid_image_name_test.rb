require_relative 'test_base'
require_relative '../../src/valid_image_name'

class ValidImageNameTest < TestBase

  include ValidImageName

  def self.hex_prefix; 'AF3'; end

  test '696',
  'invalid image_names are invalid' do
    hex = '9'*32
    [
      '',              # nothing!
      '_',             # cannot start with separator
      'name_',         # cannot end with separator
      ';;;',           # illegal char
      'ALPHA/name',    # no uppercase
      'gcc/Assert',    # no uppercase
      'alpha/name_',   # cannot end in separator
      'alpha/_name',   # cannot begin with separator
      'gcc:.',         # tag can't start with .
      'gcc:-',         # tag can't start with -
      'gcc:{}',        # bad tag
      "gcc:#{'x'*129}",# tag too long
      '-/gcc/assert:23',    # - is illegal hostname
      '-x/gcc/assert:23',   # -x is illegal hostname
      'x-/gcc/assert:23',   # x- is illegal hostname
      '/gcc/assert',        # remote-name can't start with /
      'gcc_assert@sha256:1234567890123456789012345678901',  # >=32 hex-digits
      "gcc_assert!sha256-2:#{hex}",  # need @ to start digest
      "gcc_assert@256:#{hex}",       # algorithm must start with letter
      "gcc_assert@sha256-2:#{hex}",  # alg-component must start with letter
      "gcc_assert@sha256#{hex}",     # need : to start hex-digits
    ].each do |invalid_image_name|
      refute valid_image_name?(invalid_image_name)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '697',
  'valid image_name are valid' do
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
    ).each { |valid_image_name|
      assert valid_image_name?(valid_image_name)
    }
  end

end
