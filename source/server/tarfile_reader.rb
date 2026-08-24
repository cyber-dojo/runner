require 'rubygems/package' # Gem::Package::TarReader
require 'stringio'

module TarFile
  class Reader
    def initialize(tar_file)
      io = StringIO.new(tar_file, 'rb')
      @reader = Gem::Package::TarReader.new(io)
    end

    def files
      @reader.each.with_object({}) do |entry, memo|
        check_ustar(entry)
        filename = entry.full_name
        content = entry.read || '' # avoid nil
        memo[filename] = content
      end
    end

    private

    # Raises unless the entry carries the ustar magic.
    #
    # Gem::Package::TarHeader.from verifies neither the header checksum nor
    # the magic. It requires only that a few fields match /\A[0-7]*\z/ once
    # stripped, and the empty string matches, so bytes that are not a tar at
    # all can parse into entries with junk names. The magic is what holds
    # them out.
    def check_ustar(entry)
      magic = entry.header.magic
      return if magic == USTAR

      raise Gem::Package::TarInvalidError, "#{magic.inspect} is not #{USTAR.inspect}"
    end

    USTAR = 'ustar'.freeze
  end
end
