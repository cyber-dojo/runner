require 'securerandom'

class Random
  # SecureRandom asks the OS for its bytes on every call, rather than drawing
  # on state this object is holding. config.ru builds the Context while puma
  # preloads the app, and puma then forks its workers, so state held here
  # would be identical in every one of them: two workers answering test-runs
  # of the same kata id would build the same container name, and the daemon
  # refuses the second of them.
  def hex8
    SecureRandom.hex(4)
  end
end
