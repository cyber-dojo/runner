# https://github.com/moby/moby/blob/master/image/spec/v1.1.md
# http://stackoverflow.com/questions/37861791/
# https://github.com/docker/distribution/blob/master/reference/reference.go

module WellFormedImageName # mix-in

  module_function

  def well_formed_image_name?(s)
    return false if s.nil?
    hostname,remote_name = split_image_name(s)
    valid_hostname?(hostname) && valid_remote_name?(remote_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def split_image_name(image_name)
    i = image_name.index('/')
    if i.nil? || i === -1 || (
        !image_name[0...i].include?('.') &&
        !image_name[0...i].include?(':') &&
         image_name[0...i] != 'localhost')
      hostname = ''
      remote_name = image_name
    else
      hostname = image_name[0..i-1]
      remote_name = image_name[i+1..-1]
    end
    [hostname,remote_name]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  CH = 'a-zA-Z0-9'
  COMPONENT = "([#{CH}]|[#{CH}][#{CH}-]*[#{CH}])"
  PORT = '[\d]+'
  HOSTNAME = /^(#{COMPONENT}(\.#{COMPONENT})*)(:(#{PORT}))?$/

  def valid_hostname?(hostname)
    hostname === '' || hostname =~ HOSTNAME
  end

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

  def valid_remote_name?(remote_name)
    remote_name =~ REMOTE_NAME
  end

end
