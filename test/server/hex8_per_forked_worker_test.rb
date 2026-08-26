require_relative '../test_base'

class Hex8PerForkedWorkerTest < TestBase

  test 'f2Jd10', %w(
  | hex8 does not answer from state the Random is holding
  | because config.ru builds the Context while puma preloads the app, and
  | puma then forks Etc.nprocessors workers, each holding a Random whose
  | state is identical to every one of its siblings
  | two workers answering presses of the same kata id would otherwise build
  | the same container name, and the daemon refuses the second with a 409
  ) do
    seed = 1234

    # Two Randoms seeded alike hold what forked workers hold, which is what
    # makes them stand in for those workers here.
    assert_equal Random.new(seed).rand(1000), Random.new(seed).rand(1000), :same_state

    refute_equal Random.new(seed).hex8, Random.new(seed).hex8, :hex8
  end
end
