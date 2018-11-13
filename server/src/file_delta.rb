
module FileDelta

  def file_delta(was, now)
    @changed_files = {}
    @deleted_files = {}
    was.each do |filename, content|
      if !now.has_key?(filename)
        @deleted_files[filename] = content
      elsif now[filename] != content
        @changed_files[filename] = sanitized(now[filename])
      end
      now.delete(filename) # destructive
    end
    @new_files = Hash[now.map { |filename,content|
      [ filename, sanitized(content) ]
    }]
  end

end
