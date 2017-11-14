require_relative 'externals'
require_relative 'runner'
require 'json'

class MicroService

  def call(env)
    request = Rack::Request.new(env)
    @args = JSON.parse(request.body.read)
    @name = request.path_info[1..-1] # lose leading /
    body = case @name
      when /^image_pulled$/
        @name += '?'
        invoke
      when /^image_pull$/
        invoke
      when /^kata_new$/
        invoke
      when /^kata_old$/
        invoke
      when /^avatar_new$/
        invoke(avatar_name, starting_files)
      when /^avatar_old$/
        invoke(avatar_name)
      when /^run_cyber_dojo_sh$/
        invoke(avatar_name,
          new_files, deleted_files, unchanged_files, changed_files,
          max_seconds
        )
      when /^run$/
        invoke(avatar_name, visible_files, max_seconds)
      else
        {}
    end
    [ 200, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

  private

  def invoke(*args)
    runner = Runner.new(self, image_name, kata_id)
    { @name => runner.send(@name, *args) }
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{@name} #{e.message}"
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
  request_args :new_files
  request_args :deleted_files
  request_args :unchanged_files
  request_args :changed_files
  request_args :max_seconds

  request_args :visible_files

end
