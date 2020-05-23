# frozen_string_literal: true
require 'json'
require 'open3'

class ExternalBash

  class AssertError < RuntimeError
    def initialize(command, stdout, stderr, status)
      super(JSON.pretty_generate({
        command:command,
        stdout:stdout,
        stderr:stderr,
        status:status
      }))
    end
  end

  def initialize(externals)
    @externals = externals
  end

  def exec(command)
    stdout,stderr,r = Open3.capture3(command)
    status = r.exitstatus
    unless status === 0 && stderr.empty?
      log(command, stdout, stderr, status)
    end
    [ stdout, stderr, status ]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def assert(command)
    stdout,stderr,r = Open3.capture3(command)
    status = r.exitstatus
    unless stderr.empty?
      log(command, stdout, stderr, status)
    end
    unless status === 0
      fail AssertError.new(command, stdout, stderr, status)
    end
    stdout
  end

  private

  def log(command, stdout, stderr, status)
    logger.write("command:#{command}:")
    logger.write("stdout:#{stdout}:")
    logger.write("stderr:#{stderr}:")
    logger.write("status:#{status}:")
  end

  def logger
    @externals.logger
  end

end