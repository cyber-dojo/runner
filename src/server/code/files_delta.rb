# frozen_string_literal: true
module FilesDelta

  def files_delta(was, now)
    changed = {}
    deleted = []
    was.each do |filename, content|
      if !now.has_key?(filename)
        deleted << filename
      elsif now[filename]['content'] != content
        changed[filename] = now[filename]
      end
      now.delete(filename) # destructive
    end
    created = now
    [created,deleted.sort,changed]
  end

end
