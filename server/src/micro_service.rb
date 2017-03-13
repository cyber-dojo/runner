require 'sinatra/base'
require 'json'
require_relative 'externals'
require_relative 'runner'

class MicroService < Sinatra::Base

  get '/image_pulled?' do
    getter(__method__, image_name)
  end

  post '/image_pull' do
    poster(__method__, image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  post '/run' do
    poster(__method__, image_name, avatar_name, visible_files, max_seconds)
  end

  private

  def getter(name, *args)
    runner_json('GET /', name, *args)
  end

  def poster(name, *args)
    runner_json('POST /', name, *args)
  end

  def runner_json(prefix, caller, *args)
    name = caller.to_s[prefix.length .. -1]
    { name => runner.send(name, *args) }.to_json
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{caller} #{e.message}"
    { 'exception' => e.message }.to_json
  end

  # - - - - - - - - - - - - - - - -

  include Externals

  def runner
    Runner.new(self)
  end

  def self.request_args(*names)
    names.each { |name|
      define_method name, &lambda { args[name.to_s] }
    }
  end

  request_args :image_name, :avatar_name, :visible_files, :max_seconds

  def args
    @args ||= JSON.parse(request_body)
  end

  def request_body
    request.body.rewind
    request.body.read
  end

end
