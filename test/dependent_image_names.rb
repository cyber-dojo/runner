# frozen_string_literal: true
require_relative 'server/data/display_names'
require_relative 'server/http_proxy/languages_start_points'
require_relative '../app/code/context'

class Dependent

  def image_names
    @image_names ||= read_image_names
  end

  private

  def read_image_names
    # The image_names must be present on the node when the runner-server
    # is started so they populate context.puller (see config.ru)
    # otherwise tests calling run_cyber_dojo_sh() will return 'pulling'
    context = Context.new
    all = ['alpine:latest'] # Used to show bash is required (alpine only has sh)
    display_names.each do |display_name|
      manifest = languages_start_points.manifest(display_name)
      all << manifest['image_name']
    end
    all
  end

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

# - - - - - - - - - - - - - - - - - - - - -

def run
  Dependent.new.image_names.each do |image_name|
    puts image_name
  end
end

# - - - - - - - - - - - - - - - - - - - - -

run if __FILE__ == $PROGRAM_NAME
