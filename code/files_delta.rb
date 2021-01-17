# frozen_string_literal: true
module FilesDelta

  # before_files are in this format:
  #    { "hiker.c" => "#include..." }
  # after_files are in this format:
  #    { "hiker.c" => { "content": "#include...", truncated: false } }

  def files_delta(before_files, after_files)
    new, changed = {}, {}
    before_filenames = before_files.keys
    after_files.each do |filename, file|
      if !before_filenames.include?(filename)
        new[filename] = after_files[filename]
      elsif before_files[filename] != file['content']
        changed[filename] = after_files[filename]
      end
    end
    deleted = {} # deprecated
    [ new, deleted, changed ]
  end

end
