require 'path_coverage'

# Measures which paths through each decision and method the server tests take,
# alongside SimpleCov's line and branch coverage (coverage.rb), and prints each
# path no test took. A method with more than 8 paths fails; run.sh checks the
# report this writes. Only the server image has the path_coverage gem, so only
# a server run requires this file.

PATHS_CODE_GLOB = 'source/**/*.rb'
# The same tests as coverage.rb's test tab. The helpers in test/ and
# test/doubles are shared with the client tests, so hold paths only the
# client takes.
PATHS_TEST_GLOBS = ['test/server/**/*.rb', 'test/dual/**/*.rb'].freeze

PathCoverage.start do
  root(ENV.fetch('APP_DIR'))
  coverage_dir("#{ENV.fetch('COVERAGE_ROOT')}/paths")
  report(:gaps, :summary)
  max_paths(8)
  cover(PATHS_CODE_GLOB)
  PATHS_TEST_GLOBS.each { |glob| cover(glob) }
  skip('source/config/**/*.rb')
  # The metrics check: run after the tests, never by them.
  skip('test/server/check_test_metrics.rb')
  group(ENV.fetch('COVERAGE_CODE_TAB_NAME'), PATHS_CODE_GLOB)
  group(ENV.fetch('COVERAGE_TEST_TAB_NAME'), *PATHS_TEST_GLOBS)
end
