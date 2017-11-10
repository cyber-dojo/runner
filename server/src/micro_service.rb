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
      when /kata_new/
        body = invoke('kata_new')
      when /kata_old/
        body = invoke('kata_old')
      when /avatar_new/
        body = invoke('avatar_new', avatar_name, starting_files)
      when /avatar_old/
        body = invoke('avatar_old', avatar_name)
      when /run_cyber_dojo_sh/
        body = invoke('run_cyber_dojo_sh',
          avatar_name,
          deleted_filenames,
          unchanged_files,
          changed_files,
          new_files,
          max_seconds)
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
    log << "EXCEPTION: #{e.class.name}.#{name} #{e.message}"
    { 'exception' => e.message }
  end

  # - - - - - - - - - - - - - - - -

  include Externals

  def self.request_args(*names)
    names.each { |name|
      define_method name, &lambda { @args[name.to_s] }
    }
  end

  request_args :image_name
  request_args :kata_id
  request_args :avatar_name
  request_args :starting_files
  request_args :deleted_filenames
  request_args :unchanged_files
  request_args :changed_files
  request_args :new_files
  request_args :max_seconds

  request_args :visible_files

end
