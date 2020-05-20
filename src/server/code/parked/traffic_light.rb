# frozen_string_literal: true
require_relative 'rag_lambda_cache'
require_relative 'rag_lambda_creator'
require 'json'

class TrafficLight

  def initialize(external)
    @external = external
    @cache = RagLambdaCache.new(external)
  end

  def sha
    { 'sha' => ENV['SHA'] }
  end

  def alive?
    { 'alive?' => true }
  end

  def ready?
    { 'ready?' => runner.ready? }
  end

  def colour(image_name, id, stdout, stderr, status)
    diagnostic = {
      'image_name' => image_name,
      'id' => id,
      'stdout' => stdout,
      'stderr' => stderr,
      'status' => status
    }

    begin
      cached = @cache.get(image_name, id)
    rescue RagLambdaCreator::Error => error
      diagnostic['info'] = error.info
      diagnostic['message'] = error.message
      diagnostic['source'] = error.source unless error.source.nil?
      return logged_faulty(diagnostic)
    end

    begin
      rag = cached[:fn].call(stdout, stderr, status)
    rescue => error
      diagnostic['info'] = 'call(lambda) raised an exception'
      diagnostic['message'] = error.message
      diagnostic['source'] = cached[:source]
      return logged_faulty(diagnostic)
    end

    rag = rag.to_s
    unless %w( red amber green ).include?(rag)
      diagnostic['info'] = "call(lambda) is '#{rag}' which is not 'red'|'amber'|'green'"
      diagnostic['source'] = cached[:source]
      return logged_faulty(diagnostic)
    end

    { 'colour' => rag }
  end

  #def new_image(image_name)
  #  @cache.new_image(image_name ,'111111')
  #end
  # The idea is that puller will be incorporated inside ragger
  # and when it pulls a new image, it will inform ragger, which
  # will run TrafficLight.new_image(...)
  # So '111111' will indicate a runner.run_cyber_dojo_sh() call
  # coming from ragger via a poke from puller.

  private

  def logged_faulty(diagnostic)
    result = {
      'diagnostic' => diagnostic,
      'colour' => 'faulty'
    }
    log << JSON.pretty_generate(result)
    result
  end

  def runner
    @external.runner
  end

  def log
    @external.log
  end

end
