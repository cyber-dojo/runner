
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

  def valid_hostname?(hostname)
    return true if hostname === ''
    ch = 'a-zA-Z0-9'
    component = "([#{ch}]|[#{ch}][#{ch}-]*[#{ch}])"
    port = '[\d]+'
    hostname =~ /^(#{component}(\.#{component})*)(:(#{port}))?$/
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def valid_remote_name?(remote_name)
    alpha_numeric = '[a-z0-9]+'
    separator = '([.]{1}|[_]{1,2}|[-]+)'
    component = "#{alpha_numeric}(#{separator}#{alpha_numeric})*"
    name = "#{component}(/#{component})*"
    tag = '[\w][\w.-]{0,127}'

    digest_component = '[A-Za-z][A-Za-z0-9]*'
    digest_separator = '[-_+.]'
    digest_algorithm = "#{digest_component}(#{digest_separator}#{digest_component})*"
    digest_hex = "[0-9a-fA-F]{32,}"
    digest = "#{digest_algorithm}[:]#{digest_hex}"
    remote_name =~ /^(#{name})(:(#{tag}))?(@#{digest})?$/
  end

end
