# frozen_string_literal: true
require_relative 'empty'

module TrafficLight

  def set_traffic_light
    if @result['run_cyber_dojo_sh'][:timed_out]
      return
    end

    rag_src = @result['rag_src']
    
    if rag_src.nil?
      @result.merge!({ 'colour' => 'faulty' })
      @result['diagnostic'] ||= {}
      @result['diagnostic'].merge!({
        'image_name' => image_name,
        'id' => id,
        'info' => "no /usr/local/bin/red_amber_green.rb in #{image_name}"
      })
      return
    end

    begin
      rag_lambda = Empty.binding.eval(rag_src)
    rescue Exception => error
      @result.merge!({ 'colour' => 'faulty' })
      @result['diagnostic'] ||= {}
      @result['diagnostic'].merge!({
        'image_name' => image_name,
        'id' => id,
        'info' => 'eval(rag_lambda) raised an exception',
        'name' => error.class.name,
        'message' => error.message.split("\n"),
        'rag_lambda' => rag_src.split("\n")
      })
      return
    end

    begin
      stdout = @result['run_cyber_dojo_sh'][:stdout]['content']
      stderr = @result['run_cyber_dojo_sh'][:stderr]['content']
      status = @result['run_cyber_dojo_sh'][:status]
      colour = rag_lambda.call(stdout, stderr, status).to_s
    rescue => error
      @result.merge!({ 'colour' => 'faulty' })
      @result['diagnostic'] ||= {}
      @result['diagnostic'].merge!({
        'image_name' => image_name,
        'id' => id,
        'info' => 'rag_lambda.call raised an exception',
        'name' => error.class.name,
        'message' => error.message.split("\n"),
        'rag_lambda' => rag_src.split("\n")
      })
      return
    end

    unless colour === 'red' || colour === 'amber' || colour === 'green'
      @result.merge!({ 'colour' => 'faulty' })
      @result['diagnostic'] ||= {}
      @result['diagnostic'].merge!({
        'image_name' => image_name,
        'id' => id,
        'info' => "rag_lambda.call is '#{colour}' which is not 'red'|'amber'|'green'",
        'rag_lambda' => rag_src.split("\n")
      })
      return
    end

    @result.merge!({ 'colour' => colour })
  end

end
