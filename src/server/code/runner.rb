# frozen_string_literal: true
require_relative 'time_out_runner'

class Runner

  def initialize(externals)
    @externals = externals
  end

  def alive?(_args={})
    { 'alive?' => true }
  end

  def ready?(_args={})
    { 'ready?' => true }
  end

  def sha(_args={})
    { 'sha' => ENV['SHA'] }
  end

  def run_cyber_dojo_sh(args)
    id = args['id']
    files = args['files']
    if args.has_key?('manifest')
      manifest = args['manifest']
    else
      manifest = {
        'image_name' => args['image_name'], 
        'max_seconds' => args['max_seconds']
      }
    end
    TimeOutRunner.new(@externals, id, files, manifest).run_cyber_dojo_sh
  end

end
