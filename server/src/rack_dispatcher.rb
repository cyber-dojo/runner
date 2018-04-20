require_relative 'runner'
require_relative 'well_formed_args'
require 'rack'

class RackDispatcher # stateless

  def initialize(external, request = Rack::Request)
    @request = request
    @external = external
  end

  attr_reader :external

  def call(env)
    request = @request.new(env)
    name, args = name_args(request)
    runner = Runner.new(external)
    triple({ name => runner.public_send(name, *args) })
  rescue => error
    #puts error.backtrace
    triple({ 'exception' => error.message })
  end

  private # = = = = = = = = = = = =

  def name_args(request)
    name = request.path_info[1..-1] # lose leading /
    @well_formed_args = WellFormedArgs.new(request.body.read)
    args = case name
      when /^kata_new$/,
           /^kata_old$/     then [image_name, kata_id]
      when /^avatar_new$/   then [image_name, kata_id, avatar_name, starting_files]
      when /^avatar_old$/   then [image_name, kata_id, avatar_name]
      when /^run_cyber_dojo_sh$/
        [image_name, kata_id, avatar_name,
         new_files, deleted_files, unchanged_files, changed_files,
         max_seconds]
    end
    [name, args]
  end

  # - - - - - - - - - - - - - - - -

  def triple(body)
    [ 200, { 'Content-Type' => 'application/json' }, [ body.to_json ] ]
  end

  # - - - - - - - - - - - - - - - -

  def self.well_formed_args(*names)
      names.each do |name|
        define_method name, &lambda { @well_formed_args.send(name) }
      end
  end

  well_formed_args :image_name,
                   :kata_id,
                   :avatar_name,
                   :starting_files,
                   :new_files,
                   :deleted_files,
                   :unchanged_files,
                   :changed_files,
                   :max_seconds
end
