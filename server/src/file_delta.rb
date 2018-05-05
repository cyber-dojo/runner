
module FileDelta

  def file_delta(was, now)
    @unchanged_files = {}
    @changed_files = {}
    @deleted_files = {}
    was.each do |filename, content|
      if !now.has_key?(filename)
        @deleted_files[filename] = content
      elsif now[filename] == content
        @unchanged_files[filename] = now[filename]
      else
        @changed_files[filename] = now[filename]
      end
      now.delete(filename) # destructive
    end
    @new_files = now
  end

end
