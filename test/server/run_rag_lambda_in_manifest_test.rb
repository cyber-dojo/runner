require_relative '../test_base'
require_code 'context'

class RunRagLambdaInManifestTest < TestBase

  alpine_test '1833b0', %w(
  | when the manifest contains colour key, its value is the red-amber-green Ruby lambda
  | previously found in the /usr/bin/local/red_amber_green.rb file in the languages image
  | which the core run_cyber_dojo_sh() function uses instead of docker-run cat'ing 
  | the file out of the languages image.
  ) do

    assert_equal "ghcr.io/cyber-dojo-languages/gcc_assert:2733119", image_name
    set_context({ logger: StdoutLoggerSpy.new })
    puller.add(image_name)

    result = run_cyber_dojo_sh({ :rag_lambda => alpine_c_assert_rag_lambda })

    assert_equal 'red', result['outcome']
    message = "Read red-amber-green lambda from #{image_name}"
    refute logger.logged.include?(message), 'lambda still being read from image'
  end

  alpine_test '1833b1', %w(
  | when the red-amber-green Ruby lambda in the manifest is malformed
  | a fault colour is returned
  ) do
    assert_equal "ghcr.io/cyber-dojo-languages/gcc_assert:2733119", image_name
    set_context({ logger: StdoutLoggerSpy.new })
    puller.add(image_name)

    result = run_cyber_dojo_sh({ :rag_lambda => 'x' + alpine_c_assert_rag_lambda })

    assert_equal 'faulty', result['outcome']
    message = "Read red-amber-green lambda from #{image_name}"
    refute logger.logged.include?(message), 'lambda still being read from image'
  end
end

def alpine_c_assert_rag_lambda
  [
    "lambda { |stdout, stderr, status|",
    "  output = stdout + stderr",
    "  return :green if status == 0",
    "  return :red   if /(.*)Assertion(.*)failed/.match(output)",
    "  return :amber",
    "}"
  ].join("\n")
end
