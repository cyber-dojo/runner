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
    image_name = args['image_name']
    max_seconds = args['max_seconds']
    manifest = { 'image_name' => image_name, 'max_seconds' => max_seconds }
    TimeOutRunner.new(@externals, id, files, manifest).run_cyber_dojo_sh
  end

end
