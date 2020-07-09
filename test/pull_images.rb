# frozen_string_literal: true
require_relative 'server/test_base'

class ImagePrePuller < TestBase

  def initialize(arg)
    super(arg)
  end

  def pull_images
    # Don't use context from TestBase as its logger is a StdoutLoggerSpy.
    context = Context.new
    display_names.each do |display_name|
      manifest = languages_start_points.manifest(display_name)
      image_name = manifest['image_name']
      command = "docker pull #{image_name}"
      context.sheller.capture(command)
      puts image_name
    end
    # Used in tests showing bash is required (busybox only has sh)
    # and need to avoid run_cyber_dojo_sh() returning 'pulling' response.
    context.sheller.capture('docker pull busybox:latest')
  end

  private

  def display_names
    [
      # Server-side tests
      ALPINE_DISPLAY_NAME,
      DEBIAN_DISPLAY_NAME,
      UBUNTU_DISPLAY_NAME,
      'Python, pytest', # Used in traffic-light tests
      # Client-side tests
      'VisualBasic, NUnit',
    ]
  end

end

ImagePrePuller.new(nil).pull_images
