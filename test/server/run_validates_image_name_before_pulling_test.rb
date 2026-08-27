require_relative '../test_base'

class RunValidatesImageNameBeforePullingTest < TestBase

  test 'B3nQ7k', %w[
  | run_cyber_dojo_sh rejects a malformed manifest image_name itself,
  | before the puller is consulted,
  | so the rejection does not rest on pull_image reaching tagged_image_name
  ] do
    set_context(puller: spy = PullerSpy.new)

    assert_raises(Docker::MalformedImageName) do
      run_cyber_dojo_sh(image_name: 'UPPERCASE/name:latest')
    end

    refute spy.called?, 'the puller was consulted before the image_name was validated'
  end
end
