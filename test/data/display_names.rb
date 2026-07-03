# frozen_string_literal: true
# The languages-start-points manifests now report each language and
# test-framework version in separate fields, so the display_name (the key used
# by both the /manifests endpoint and inspect.rb, and hence the key in the
# generated fixture test/data/languages_start_points.manifests.json) no longer
# embeds the version. These constants are those de-versioned fixture keys,
# looked up in test_base.rb.
module DisplayNames
  ALPINE = 'C (gcc), assert'
  DEBIAN = 'Perl, Test::Simple'
  UBUNTU = 'C (clang), assert'
end
