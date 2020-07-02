# frozen_string_literal: true

module Docker # mix-in

  module_function

  def tagged_image_name(s)
    # The image_names harvested from the nodes have an
    # explicit :latest tag. The image_name in pull_image()
    # and run_cyber_dojo_sh()'s manifest must match.
    # eg 'cdf/gcc_assert' ==> 'cdf/gcc_assert:latest'
    i = s.index('/')
    if i.nil? || remote_name?(s[0...i])
      match = s.match(REMOTE_NAME)
      name = match[1]
      tag = match[8]
      digest = match[9]
    else
      host_name,remote_name = cut(s, i)
      match = remote_name.match(REMOTE_NAME)
      name = "#{host_name}/#{match[1]}"
      tag = match[8]
      digest = match[9]
    end
    if tag.nil?
      tag = 'latest'
    end
    "#{name}:#{tag}#{digest}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name?(s)
    return false if s.nil?
    return false unless s.is_a?(String)
    i = s.index('/')
    if i.nil? || remote_name?(s[0...i])
      s =~ REMOTE_NAME
    else
      host_name,remote_name = cut(s, i)
      host_name =~ HOST_NAME && remote_name =~ REMOTE_NAME
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def cut(s, i)
    # s = 'cyberdojofoundation/gcc_assert'
    # i = s.index('/') # 19
    # s[0..18]  == 'cyberdojofoundation'
    # s[20..-1] == 'gcc_assert'
    [s[0..i-1], s[i+1..-1]]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def remote_name?(s)
    dns_separator = '.'
    port_separator = ':'
    !s.include?(dns_separator) &&
      !s.include?(port_separator) &&
        s != 'localhost'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # [[host:port/]registry/]component[:tag][@digest]

  CH = 'a-zA-Z0-9'
  COMPONENT = "([#{CH}]|[#{CH}][#{CH}-]*[#{CH}])"
  PORT = '[\d]+'
  HOST_NAME = /^(#{COMPONENT}(\.#{COMPONENT})*)(:(#{PORT}))?$/

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  ALPHA_NUMERIC = '[a-z0-9]+'
  SEPARATOR = '([.]{1}|[_]{1,2}|[-]+)'
  REMOTE_COMPONENT = "#{ALPHA_NUMERIC}(#{SEPARATOR}#{ALPHA_NUMERIC})*"
  NAME = "#{REMOTE_COMPONENT}(/#{REMOTE_COMPONENT})*"
  TAG = '[\w][\w.-]{0,127}'
  DIGEST_COMPONENT = '[A-Za-z][A-Za-z0-9]*'
  DIGEST_SEPARATOR = '[-_+.]'
  DIGEST_ALGORITHM = "#{DIGEST_COMPONENT}(#{DIGEST_SEPARATOR}#{DIGEST_COMPONENT})*"
  DIGEST_HEX = "[0-9a-fA-F]{32,}"
  DIGEST = "#{DIGEST_ALGORITHM}[:]#{DIGEST_HEX}"
  REMOTE_NAME = /^(#{NAME})(:(#{TAG}))?(@#{DIGEST})?$/

end

Docker.freeze

# http://stackoverflow.com/questions/37861791/
# https://github.com/moby/moby/blob/master/image/spec/v1.1.md
# https://github.com/docker/distribution/blob/master/reference/reference.go
