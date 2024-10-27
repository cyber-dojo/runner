# frozen_string_literal: true
module Utf8
  def self.clean(str)
    # force an encoding change
    # if encoding is already utf-8 then encoding
    # to utf-8 is a no-op and invalid byte sequences
    # are not detected.
    str = str.encode('UTF-16', 'UTF-8', invalid: :replace, replace: '')
    str = str.encode('UTF-8', 'UTF-16')
  end
end

# http://robots.thoughtbot.com/fight-back-utf-8-invalid-byte-sequences
