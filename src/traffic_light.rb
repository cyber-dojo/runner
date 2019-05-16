
class TrafficLight

  def initialize(external)
    @external = external
    @cache = {}
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def colour(stdout, stderr, status, image_name)
    rag_lambda = rag_lambda(image_name) { get_rag_lambda(image_name) }
    colour = rag_lambda.call(stdout, stderr, status)
    unless [:red,:amber,:green].include?(colour)
      log << rag_message(colour.to_s)
      colour = :amber
    end
    colour.to_s
  rescue => error
    log << rag_message(error.message)
    'amber'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def rag_lambda(image_name, &block)
    @cache[image_name] ||= block.call
  end

  private

  def get_rag_lambda(image_name)
    command = 'cat /usr/local/bin/red_amber_green.rb'
    docker_command = <<~SHELL.strip
      docker run                \
        --interactive           \
        --rm                    \
        #{image_name}           \
          bash -c '#{command}'
    SHELL
    catted_source = shell.assert(docker_command)
    eval(catted_source)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def rag_message(message)
    "red_amber_green lambda error mapped to :amber\n#{message}"
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def shell
    @external.shell
  end

  def log
    @external.log
  end

end
