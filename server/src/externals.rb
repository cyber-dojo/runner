require_relative 'basher'
require_relative 'disk_writer'
require_relative 'ledger_writer'
require_relative 'log_writer'

module Externals # mix-in

  def bash
    @bash ||= Basher.new
  end
  def bash=(doppel)
    @bash = doppel
  end

  def disk
    @disk ||= DiskWriter.new
  end

  def log
    @log ||= LogWriter.new
  end

  def ledger
    @ledger ||= LedgerWriter.new
  end

end
