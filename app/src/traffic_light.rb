# frozen_string_literal: true
require_relative 'empty'

module TrafficLight

  def traffic_light(image_name, id, rag_src, stdout, stderr, status)
    if rag_src.nil?
      return {
        'colour' => 'faulty',
        'diagnostic' => {
          'image_name' => image_name,
          'id' => id,
          'info' => "no /usr/local/bin/red_amber_green.rb in #{image_name}"
        }
      }
    end

    begin
      rag_lambda = Empty.binding.eval(rag_src)
    rescue Exception => error
      return {
        'colour' => 'faulty',
        'diagnostic' => {
          'image_name' => image_name,
          'id' => id,
          'info' => 'eval(rag_lambda) raised an exception',
          'message' => error.message.lines,
          'rag_lambda' => rag_src.lines
        }
      }
    end

    begin
      stdout = stdout['content']
      stderr = stderr['content']
      colour = rag_lambda.call(stdout, stderr, status).to_s
    rescue => error
      return {
        'colour' => 'faulty',
        'diagnostic' => {
          'image_name' => image_name,
          'id' => id,
          'info' => 'rag_lambda.call raised an exception',
          'message' => error.message.lines,
          'rag_lambda' => rag_src.lines
        }
      }
    end

    unless colour === 'red' || colour === 'amber' || colour === 'green'
      return {
        'colour' => 'faulty',
        'diagnostic' => {
          'image_name' => image_name,
          'id' => id,
          'info' => "rag_lambda.call is '#{colour}' which is not 'red'|'amber'|'green'",
          'rag_lambda' => rag_src.lines
        }
      }
    end

    { 'colour' => colour }
  end

end
