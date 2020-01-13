# frozen_string_literal: true

module SetTrafficLight

  def set_traffic_light(result, rag_src, stdout, stderr, status)
    begin
      rag_lambda = Empty.binding.eval(rag_src)
    rescue Exception => error
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'info' => 'eval(rag_lambda) raised an exception',
        'message' => error.message,
        'rag_lambda' => rag_src
      }
      return
    end

    begin
      stdout = stdout['content']
      stderr = stderr['content']
      colour = rag_lambda.call(stdout, stderr, status).to_s
    rescue => error
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'info' => 'rag_lambda.call raised an exception',
        'message' => error.message,
        'rag_lambda' => rag_src
      }
      return
    end

    unless colour === 'red' || colour === 'amber' || colour === 'green'
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'info' => "rag_lambda.call is '#{colour}' which is not 'red'|'amber'|'green'",
        'rag_lambda' => rag_src
      }
      return
    end

    result['colour'] = colour
  end

end
