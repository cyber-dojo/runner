require_relative 'externals'
require_relative 'runner'
require 'json'

class MicroService

  def call(env)
    request = Rack::Request.new(env)
    @json_args = json_args(request)
    @name = request.path_info[1..-1] # lose leading /
    @args = case @name
      when /^image_pulled$/
        @name += '?'
        []
      when /^image_pull$/
        []
      when /^kata_new$/
        []
      when /^kata_old$/
        []
      when /^avatar_new$/
        [avatar_name, starting_files]
      when /^avatar_old$/
        [avatar_name]
      when /^run_cyber_dojo_sh$/
        [avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
      when /^run$/
        [avatar_name, visible_files, max_seconds]
      else
        @name = nil
        []
      end
    [ 200, { 'Content-Type' => 'application/json' }, [ invoke.to_json ] ]
  end

  private # = = = = = = = = = = = =

  def invoke
    runner = Runner.new(self, image_name, kata_id)
    { @name => runner.send(@name, *@args) }
  rescue Exception => e
    log << "EXCEPTION: #{e.class.name}.#{@name} #{e.message}"
    { 'exception' => e.message }
  end

  # - - - - - - - - - - - - - - - -

  def json_args(request)
    JSON.parse(request.body.read)
  rescue StandardError => e
    log << "EXCEPTION: #{e.class.name}.#{__method__} #{e.message}"
    {}
  end

  # - - - - - - - - - - - - - - - -

  include Externals

  def self.request_args(*names)
    names.each { |name|
      define_method name, &lambda {
        @json_args[name.to_s]
      }
    }
  end

  request_args :image_name, :kata_id, :avatar_name
  request_args :starting_files
  request_args :new_files, :deleted_files, :unchanged_files, :changed_files
  request_args :max_seconds

  request_args :visible_files

end
