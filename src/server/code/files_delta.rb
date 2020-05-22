# frozen_string_literal: true
module FilesDelta

  # files_in (old)
  # Format == { "hiker.c" => "#include..." }
  # files_out (new)
  # Format == { "hiker.c" => { content: "#include...", truncated: false } }

  def files_delta(old, new)
    changed = {}
    deleted = {}
    old.each do |filename, content|
      if !new.has_key?(filename)
        deleted[filename] = { content: content }
      elsif new[filename][:content] != content
        changed[filename] = new[filename]
      end
      new.delete(filename) # same (destructive)
    end
    [ created=new, deleted, changed ]
  end

  # The old files are assumed to NOT be truncated.
  # To check for a changed file we only have to check the
  # new files' content. If the new file has been truncated
  # then the content must have changed since the old files
  # are assumed NON truncated.

end
