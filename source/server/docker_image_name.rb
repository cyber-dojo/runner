# Docker's own grammar for naming an image, and what the runner will accept
# from outside written in terms of it. A namespace rather than a mix-in:
# nothing includes it.
module DockerImageName
  # str does not name a docker image, so there is nothing to tag. Saying so
  # is what keeps a caller's bad argument from surfacing as a NoMethodError
  # raised on the nil that str.match answered.
  class Malformed < RuntimeError
  end

  # str names a docker image, but names whichever image was pushed to
  # :latest rather than one particular image. A start-point pointing at
  # :latest can change underneath the kata, so the runner will not take one.
  class Unversioned < RuntimeError
  end

  module_function

  LATEST = 'latest'.freeze

  # Raises unless str is a docker image name pinned to a tag other than
  # :latest, which is what the runner accepts from outside. Every way of
  # asking for :latest collapses to one check here, since tagged answers an
  # untagged name with the :latest it means. tagged is what answers the
  # malformed case.
  #
  # That takes a digest with no tag, eg name@sha256:..., down with it, and a
  # digest pins harder than any tag does. It goes anyway so that a start-point
  # is named one way. The set of images-present-on-the-node that config.ru
  # seeds NodeImages with carries digest-only references among its tags, so what
  # the refusal turns on is what a manifest may say, not what the seed can
  # match.
  def assert_versioned(str)
    raise Unversioned, str.inspect if tag_of(tagged(str)) == LATEST
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # Answers the tag of an image name known to carry one. The digest, which
  # holds a colon of its own, comes off first; a registry's :port cannot be
  # last, so what follows the last remaining colon is the tag.
  def tag_of(tagged)
    tagged.split('@', 2).first.split(':').last
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # The image_names harvested from the nodes have an
  # explicit :latest tag. The image_name in pull_image()
  # and run_cyber_dojo_sh()'s manifest must match.
  # eg 'cdf/gcc_assert' ==> 'cdf/gcc_assert:latest'
  def tagged(str)
    raise Malformed, str.inspect unless valid?(str)

    name, match = name_and_match(str)
    "#{name}:#{match[8] || LATEST}#{match[9]}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # Answers the name as written, and the REMOTE_NAME match holding its tag
  # and digest. A registry host comes off first, REMOTE_NAME not describing
  # one, and is put back on the answered name.
  def name_and_match(str)
    index = str.index('/')
    if index.nil? || remote_name?(str[0...index])
      match = str.match(REMOTE_NAME)
      [match[1], match]
    else
      host_name, remote_name = cut(str, index)
      match = remote_name.match(REMOTE_NAME)
      ["#{host_name}/#{match[1]}", match]
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def valid?(str)
    return false if str.nil?
    return false unless str.is_a?(String)

    index = str.index('/')
    if index.nil? || remote_name?(str[0...index])
      str =~ REMOTE_NAME
    else
      host_name, remote_name = cut(str, index)
      host_name =~ HOST_NAME && remote_name =~ REMOTE_NAME
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def cut(str, index)
    # str = 'cyberdojofoundation/gcc_assert'
    # index = str.index('/') # 19
    # str[0..18]  == 'cyberdojofoundation'
    # str[20..] == 'gcc_assert'
    [str[0..index - 1], str[index + 1..]]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def remote_name?(str)
    dns_separator = '.'
    port_separator = ':'
    !str.include?(dns_separator) &&
      !str.include?(port_separator) &&
      str != 'localhost'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # [[host:port/]registry/]component[:tag][@digest]

  CH = 'a-zA-Z0-9'.freeze
  COMPONENT = "([#{CH}]|[#{CH}][#{CH}-]*[#{CH}])".freeze
  PORT = '[\d]+'.freeze
  HOST_NAME = /^(#{COMPONENT}(\.#{COMPONENT})*)(:(#{PORT}))?$/.freeze

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ALPHA_NUMERIC = '[a-z0-9]+'.freeze
  SEPARATOR = '([.]{1}|[_]{1,2}|[-]+)'.freeze
  REMOTE_COMPONENT = "#{ALPHA_NUMERIC}(#{SEPARATOR}#{ALPHA_NUMERIC})*".freeze
  NAME = "#{REMOTE_COMPONENT}(/#{REMOTE_COMPONENT})*".freeze
  TAG = '[\w][\w.-]{0,127}'.freeze
  DIGEST_COMPONENT = '[A-Za-z][A-Za-z0-9]*'.freeze
  DIGEST_SEPARATOR = '[-_+.]'.freeze
  DIGEST_ALGORITHM = "#{DIGEST_COMPONENT}(#{DIGEST_SEPARATOR}#{DIGEST_COMPONENT})*".freeze
  DIGEST_HEX = '[0-9a-fA-F]{32,}'.freeze
  DIGEST = "#{DIGEST_ALGORITHM}[:]#{DIGEST_HEX}".freeze
  REMOTE_NAME = /^(#{NAME})(:(#{TAG}))?(@#{DIGEST})?$/.freeze
end

DockerImageName.freeze

# http://stackoverflow.com/questions/37861791/
# https://github.com/moby/moby/blob/master/image/spec/v1.1.md
# https://github.com/docker/distribution/blob/master/reference/reference.go
