require 'sinatra/base'
require 'json'
require_relative 'externals'
require_relative 'runner'

class MicroService < Sinatra::Base

   get '/image_pulled?' do; getter(__method__, image_name); end
  post '/image_pull'    do; poster(__method__, image_name); end

  # - - - - - - - - - - - - - - - - - - - - -

  post '/kata_new' do
    no_op(__method__, image_name, kata_id)
  end

  post '/kata_old' do
    no_op(__method__, image_name, kata_id)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  post '/avatar_new' do
    no_op(__method__, image_name, kata_id, avatar_name, starting_files)
  end

  post '/avatar_old' do
    no_op(__method__, image_name, kata_id, avatar_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  post '/run' do
    args  = [image_name, kata_id, avatar_name]
    args += [visible_files, max_seconds]
    poster(__method__, *args)
  end

  private

  def no_op(name, *_args);
    name = name.to_s['POST /'.length .. -1]
    { name => {} }.to_json;
  end

  def getter(name, *args); runner_json( 'GET /', name, *args); end
  def poster(name, *args); runner_json('POST /', name, *args); end

  def runner_json(prefix, caller, *args)
    name = caller.to_s[prefix.length .. -1]
    { name => runner.send(name, *args) }.to_json
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{caller} #{e.message}"
    { 'exception' => e.message }.to_json
  end

  # - - - - - - - - - - - - - - - -

  include Externals

  def runner; Runner.new(self); end

  def self.request_args(*names)
    names.each { |name|
      define_method name, &lambda { args[name.to_s] }
    }
  end

  request_args :image_name, :kata_id, :avatar_name
  request_args :starting_files
  request_args :deleted_filenames, :visible_files, :max_seconds

  def args; @args ||= JSON.parse(request_body); end

  def request_body
    request.body.rewind
    request.body.read
  end

end
