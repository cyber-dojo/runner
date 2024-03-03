# frozen_string_literal: true
require_relative 'synchronized_set'
require_relative 'tagged_image_name'

class Puller
  def initialize(context)
    @context = context
    @pulled  = SynchronizedSet.new
    @pulling = SynchronizedSet.new
  end

  # - - - - - - - - - - - - - - - - - - -

  def image_names
    @pulled.to_a
  end

  # - - - - - - - - - - - - - - - - - - -

  def add(image_name)
    @pulled.add(image_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def pull_image(id:, image_name:)
    image_name = ::Docker.tagged_image_name(image_name)
    if @pulled.include?(image_name)
      :pulled
    else
      if @pulling.add?(image_name)
        threader.thread('pulls-image') do
          threaded_pull_image(id, image_name)
        end
      end
      :pulling
    end
  end

  private

  def threaded_pull_image(_id, image_name)
    t0 = Time.now
    command = "docker pull #{image_name}"
    stdout, stderr, status = sheller.capture(command)
    if status == 0
      t1 = Time.now
      add(image_name)
      took = (t1 - t0).round(1)
      logger.log("Pulled docker image #{image_name} (#{took} secs)")
    else
      logger.log("Failed to pull docker image #{image_name}, stdout=#{stdout}, stderr=#{stderr}")
    end
  ensure
    @pulling.delete(image_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def logger
    @context.logger
  end

  def sheller
    @context.sheller
  end

  def threader
    @context.threader
  end
end
