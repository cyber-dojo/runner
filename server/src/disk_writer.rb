
class DiskWriter

  def initialize(_parent)
  end

  def write(pathed_filename, content)
    File.open(pathed_filename, 'w') { |fd|
      fd.write(content)
    }
  end

end
