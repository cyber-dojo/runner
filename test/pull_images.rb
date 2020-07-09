# frozen_string_literal: true
require_relative 'server/data/display_names'
require_relative 'server/http_proxy/languages_start_points'
require_relative '../app/code/context'

class ImagePrePuller

  def pull_images
    context = Context.new
    display_names.each do |display_name|
      manifest = languages_start_points.manifest(display_name)
      image_name = manifest['image_name']
      command = "docker pull #{image_name}"
      context.sheller.capture(command)
      puts image_name
    end
    # Used in tests showing bash is required (alpine only has sh)
    # and need to avoid run_cyber_dojo_sh() returning 'pulling' response.
    context.sheller.capture('docker pull alpine:latest')
  end

  private

  def languages_start_points
    HttpProxy::LanguagesStartPoints.new
  end

  def display_names
    [
      # Server-side tests
      DisplayNames::ALPINE,
      DisplayNames::DEBIAN,
      DisplayNames::UBUNTU,
      'Python, pytest', # Used in traffic-light tests
      # Client-side tests
      'VisualBasic, NUnit',
    ]
  end

end

ImagePrePuller.new.pull_images
