# frozen_string_literal: true
require_relative 'data/display_names'

def run
  [
    # Server-side tests
    DisplayNames::ALPINE,
    DisplayNames::DEBIAN,
    DisplayNames::UBUNTU,
    'Python, pytest', # Used in traffic-light tests
    # Client-side tests
    'VisualBasic, NUnit',
  ].each do |display_name|
    puts display_name
  end
end

# - - - - - - - - - - - - - - - - - - - - -

run if __FILE__ == $PROGRAM_NAME
