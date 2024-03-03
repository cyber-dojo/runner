# frozen_string_literal: true
# mix-in
module Docker
  module_function

  def tagged_image_name(str)
    # The image_names harvested from the nodes have an
    # explicit :latest tag. The image_name in pull_image()
    # and run_cyber_dojo_sh()'s manifest must match.
    # eg 'cdf/gcc_assert' ==> 'cdf/gcc_assert:latest'
    index = str.index('/')
    if index.nil? || remote_name?(str[0...index])
      match = str.match(REMOTE_NAME)
      name = match[1]
      tag = match[8]
      digest = match[9]
    else
      host_name, remote_name = cut(str, index)
      match = remote_name.match(REMOTE_NAME)
      name = "#{host_name}/#{match[1]}"
      tag = match[8]
      digest = match[9]
    end
    tag = 'latest' if tag.nil?
    "#{name}:#{tag}#{digest}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name?(str)
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

  CH = 'a-zA-Z0-9'
  COMPONENT = "([#{CH}]|[#{CH}][#{CH}-]*[#{CH}])"
  PORT = '[\d]+'
  HOST_NAME = /^(#{COMPONENT}(\.#{COMPONENT})*)(:(#{PORT}))?$/.freeze

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ALPHA_NUMERIC = '[a-z0-9]+'
  SEPARATOR = '([.]{1}|[_]{1,2}|[-]+)'
  REMOTE_COMPONENT = "#{ALPHA_NUMERIC}(#{SEPARATOR}#{ALPHA_NUMERIC})*"
  NAME = "#{REMOTE_COMPONENT}(/#{REMOTE_COMPONENT})*"
  TAG = '[\w][\w.-]{0,127}'
  DIGEST_COMPONENT = '[A-Za-z][A-Za-z0-9]*'
  DIGEST_SEPARATOR = '[-_+.]'
  DIGEST_ALGORITHM = "#{DIGEST_COMPONENT}(#{DIGEST_SEPARATOR}#{DIGEST_COMPONENT})*"
  DIGEST_HEX = '[0-9a-fA-F]{32,}'
  DIGEST = "#{DIGEST_ALGORITHM}[:]#{DIGEST_HEX}"
  REMOTE_NAME = /^(#{NAME})(:(#{TAG}))?(@#{DIGEST})?$/.freeze
end

Docker.freeze

# http://stackoverflow.com/questions/37861791/
# https://github.com/moby/moby/blob/master/image/spec/v1.1.md
# https://github.com/docker/distribution/blob/master/reference/reference.go
