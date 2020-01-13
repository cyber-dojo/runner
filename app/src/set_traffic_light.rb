# frozen_string_literal: true

module SetTrafficLight

  def set_traffic_light(result, image_name, id, rag_src, stdout, stderr, status)
    if rag_src.nil?
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'image_name' => image_name,
        'id' => id,
        'info' => "no /usr/local/bin/red_amber_green.rb in #{image_name}"
      }
      return
    end

    begin
      rag_lambda = Empty.binding.eval(rag_src)
    rescue Exception => error
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'image_name' => image_name,
        'id' => id,
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
        'image_name' => image_name,
        'id' => id,
        'info' => 'rag_lambda.call raised an exception',
        'message' => error.message,
        'rag_lambda' => rag_src
      }
      return
    end

    unless colour === 'red' || colour === 'amber' || colour === 'green'
      result['colour'] = 'faulty'
      result['diagnostic'] = {
        'image_name' => image_name,
        'id' => id,
        'info' => "rag_lambda.call is '#{colour}' which is not 'red'|'amber'|'green'",
        'rag_lambda' => rag_src
      }
      return
    end

    result['colour'] = colour
  end

end
