require_relative 'test_base'
require_relative 'malformed_data'
require_relative '../../src/well_formed_image_name'

class WellFormedImageNameTest < TestBase

  include MalformedData
  include WellFormedImageName

  def self.hex_prefix
    'AF3A5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '696', %w( malformed image_name is false ) do
    malformed_image_names.each do |image_name|
      refute well_formed_image_name?(image_name)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '697', %w( well-formed image_name is true ) do
    well_formed_image_names.each { |image_name|
      assert well_formed_image_name?(image_name)
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def well_formed_image_names
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
  end

end
