
module FileDelta

  def file_delta(was, now)
    @changed_files = {}
    @deleted_files = {}
    was.each do |filename, file|
      if !now.has_key?(filename)
        @deleted_files[filename] = file
      elsif now[filename]['content'] != file['content']
        @changed_files[filename] = now[filename]
      end
      now.delete(filename) # destructive
    end
    @created_files = now
  end

end
