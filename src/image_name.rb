# http://stackoverflow.com/questions/37861791/
# https://github.com/moby/moby/blob/master/image/spec/v1.1.md
# https://github.com/docker/distribution/blob/master/reference/reference.go

module ImageName # mix-in

  module_function

  def image_name?(s)
    return false if s.nil?
    i = s.index('/')
    if i.nil? || remote_name?(s[0...i])
      s =~ REMOTE_NAME
    else
      host_name,remote_name = cut(s, i)
      host_name =~ HOST_NAME && remote_name =~ REMOTE_NAME
    end
  end

  def cut(s, i)
    [s[0..i-1], s[i+1..-1]]
  end

  def remote_name?(s)
    # '.' = DNS separator
    # ':' = port separator
    exclude?(s, '.') && exclude?(s, ':') && s != 'localhost'
  end

  def exclude?(s, c)
    !s.include?(c)
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
