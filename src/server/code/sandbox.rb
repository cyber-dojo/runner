# frozen_string_literal: true

module Sandbox

  DIR = '/sandbox' # where files are saved to in the container

  def self.in(arg)
    #     arg {         'hiker.cs' => content }
    # returns { 'sandbox/hiker.cs' => content }
    if arg.is_a?(Hash)
      # files
      arg.each.with_object({}) do |(filename,content),memo|
        memo[Sandbox.in(filename)] = content
      end
    else
      # filename: Tar likes relative paths
      unrooted = Sandbox::DIR[1..-1]
      [ unrooted, arg ].join('/')
    end
  end

  def self.out(arg)
    #     arg { 'sandbox/hiker.cs' => content }
    # returns {         'hiker.cs' => content }
    if arg.is_a?(Hash)
      # files
      arg.each.with_object({}) do |(filename,content),memo|
        memo[Sandbox.out(filename)] = content
      end
    else
      # filename
      arg[Sandbox::DIR.size..-1] # same size with / at front or back
    end
  end

end
