# frozen_string_literal: true

# Asks whether DockerImageName.tagged ever alters one of the image_names a
# test-run actually arrives with.
#
# It matters because NodeImages keys @pulled by tagged(image_name) and forget
# deletes the name it is handed. If the two forms coincide for every real name,
# forget works by coincidence and no test can show it failing. If any name
# differs, that name is the one a red test is written from.
#
# The names come from test/data/languages_start_points.manifests.json, the
# fixture the server tests drive real runs against.
#
# What it found. Of 82 image_names, none is altered by tagged. So forget and
# pull agree by coincidence rather than by construction, and the coincidence is
# not chance: every start-point names its image with an explicit tag, which the
# runner requires anyway, assert_versioned refusing a name without one. There is
# therefore no red test available for forget's keying, which is why the tagging
# it now does is stated in a comment rather than pinned by a test.
#
# Needs no gems and nothing else from source, DockerImageName requiring nothing:
#
#   docker run --rm --volume <repo>/runner:/runner:ro ruby:3.4-alpine \
#     ruby /runner/docs/profiling/check_tagged_alters_a_real_image_name.rb

require 'json'
require_relative '../../source/server/docker_image_name'

MANIFESTS = "#{__dir__}/../../test/data/languages_start_points.manifests.json"

image_names = JSON.parse(File.read(MANIFESTS))
                  .fetch('manifests')
                  .values
                  .map { |manifest| manifest['image_name'] }
                  .compact
                  .uniq
                  .sort

altered = image_names.reject do |image_name|
  DockerImageName.tagged(image_name) == image_name
rescue StandardError => e
  puts "#{image_name}: raised #{e.class}"
  true
end

puts "image_names: #{image_names.size}"
puts "altered by tagged: #{altered.size}"
altered.each do |image_name|
  puts "  #{image_name}"
  puts "  #{DockerImageName.tagged(image_name)}"
end
