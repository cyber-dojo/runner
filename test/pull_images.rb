# frozen_string_literal: true
require_relative 'server/test_base'

class ImagePrePuller < TestBase

  def initialize(arg)
    super(arg)
  end

  def pull_images
    context = Context.new(sheller:ExternalSheller.new(self))
    display_names.each do |display_name|
      manifest = languages_start_points.manifest(display_name)
      image_name = manifest['image_name']
      command = "docker pull #{image_name}"
      context.sheller.capture(command)
      puts image_name
    end
  end

  private

  def display_names
    [
      'C (gcc), assert',
      'C#, NUnit',
      'VisualBasic, NUnit',
      'Python, pytest',
      'C (clang), assert',
      'Perl, Test::Simple'
    ]
  end

end

ImagePrePuller.new(nil).pull_images
