# frozen_string_literal: true
module Sandbox
  DIR = '/sandbox' # where files are saved to in the container

  def self.in(arg)
    # eg  arg {         'hiker.cs' => content }
    # returns { 'sandbox/hiker.cs' => content }
    if arg.is_a?(Hash)
      files = arg
      files.each.with_object({}) do |(filename, content), memo|
        memo[Sandbox.in(filename)] = content
      end
    else
      filename = arg
      # Tar likes relative paths so strip leading /
      unrooted = Sandbox::DIR[1..-1]
      [unrooted, filename].join('/')
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.out(arg)
    # eg  arg { 'sandbox/hiker.cs' => content }
    # returns {         'hiker.cs' => content }
    if arg.is_a?(Hash)
      files = arg
      files.each.with_object({}) do |(filename, content), memo|
        memo[Sandbox.out(filename)] = content
      end
    else
      filename = arg
      # Sandbox::DIR had a leading / but we only need its size
      # and the size is the same with a / at the front or the back
      filename[Sandbox::DIR.size..-1]
    end
  end
end
