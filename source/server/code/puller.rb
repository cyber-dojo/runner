# frozen_string_literal: true
require_relative 'synchronized_set'

class Puller

  def initialize(context)
    @context = context
    @pulled  = SynchronizedSet.new
    @pulling = SynchronizedSet.new
  end

  # - - - - - - - - - - - - - - - - - - -

  def add(image_name)
    @pulled.add(image_name)
  end

  # - - - - - - - - - - - - - - - - - - -

  def pull_image(id:, image_name:)
    image_name = Docker::tagged_image_name(image_name)
    if !@pulled.include?(image_name)
      if @pulling.add?(image_name)
        threader.thread do
          threaded_pull_image(id, image_name)
        end
      end
      :pulling
    else
      :pulled
    end
  end

  private

  def threaded_pull_image(id, image_name)
    t0 = Time.now
    command = "docker pull #{image_name}"
    _,_,status = sheller.capture(command)
    if status === 0
      add(image_name)
      t1 = Time.now
      took = (t1 - t0).round(1)
      logger.log("Pulled docker image #{image_name} (#{took} secs)")
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
