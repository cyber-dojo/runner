# frozen_string_literal: true
module FilesDelta

  # Incoming files are in this format:
  #    { "hiker.c" => "#include..." }
  # Outgoing files are in this format:
  #    { "hiker.c" => { "content": "#include...", truncated: false } }
  
  def files_delta(old, new)
    changed = {}
    deleted = {}
    old.each do |filename, content|
      if !new.has_key?(filename)
        deleted[filename] = { 'content' => content }
      elsif new[filename]['content'] != content
        changed[filename] = new[filename]
      end
      new.delete(filename) # same (destructive)
    end
    [ new, deleted, changed ]
  end

end
