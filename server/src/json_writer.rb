require 'json'

class JsonWriter

  def write(info)
    puts JSON.pretty_generate(info)
  end

end
