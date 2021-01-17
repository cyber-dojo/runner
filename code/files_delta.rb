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

=begin
  The names of deleted files are NOT returned to the caller.

  The intended illusion in cyber-dojo is that the test run
  is happening in the browser. Thus the only way you should be
  able to delete a file is directly from the browser by clicking
  the [-] button.

  Deleted files used to be detected in files_delta() but it caused problems:

  1) It caused unwanted diffs between test runs.

     For example, if you generate coverage files, but only on a green test,
     then a green test, followed by a red test results in all the coverage files
     unhelpfully appearing as deleted files in the diff view.

  2) It resulted in files being deleted for no apparant reason!

     Suppose, in the browser, you accidentally type a rogue character into a file.
     - The file is saved into the container.
     - The os thinks it is a binary file.
     - The text-file harvester does NOT see it.
     - Its name is returned as a deleted file.
     - The browser deletes it!
=end

end
