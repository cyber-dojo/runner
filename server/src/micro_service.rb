require_relative 'externals'
require_relative 'runner'
require 'json'

class MicroService

  def call(env)
    request = Rack::Request.new(env)
    @args = JSON.parse(request.body.read)
    case request.path_info
      when /image_pulled?/
        body = invoke('image_pulled?')
      when /image_pull/
        body = invoke('image_pull')
      when /run/
        body = invoke('run', avatar_name, visible_files, max_seconds)
    end
    [ 200, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

  private

  def invoke(name, *args)
    runner = Runner.new(self, image_name, kata_id)
    { name => runner.send(name, *args) }
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{caller} #{e.message}"
    { 'exception' => e.message }
  end

  # - - - - - - - - - - - - - - - -

  include Externals

  def self.request_args(*names)
    names.each { |name|
      define_method name, &lambda { @args[name.to_s] }
    }
  end

  request_args :image_name, :kata_id
  request_args :avatar_name, :visible_files, :max_seconds

end
