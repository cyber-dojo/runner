# frozen_string_literal: true
require 'English'
require 'minitest/autorun'
require 'minitest/ci'
require_relative 'require_code'

Minitest::Ci.report_dir = "#{ENV.fetch('REPORTS_ROOT', nil)}/junit"

class Id58TestBase < Minitest::Test
  def initialize(arg)
    @_id58 = nil
    @_name58 = nil
    super
  end

  @@args = (ARGV.sort.uniq - ['--']) # eg 2m4
  @@seen_ids = {}
  @@timings = {}

  def self.define_test(os, display_name, id58_suffix, *lines, &test_block)
    src = test_block.source_location
    src_file = File.basename(src[0])
    src_line = src[1].to_s
    id58 = checked_id58(os, id58_suffix, lines)
    return unless @@args == [] || @@args.any? { |arg| id58.include?(arg) }

    name58 = lines.join(space = ' ')
    execute_around = lambda {
      ENV['ID58'] = id58
      p [id58, src_file].join(':') if ENV['SHOW_TEST_IDS'] == 'true'
      @_os = os
      @_display_name = display_name
      @_id58 = id58
      @_name58 = name58
      id58_setup
      begin
        t1 = Time.now
        instance_eval(&test_block)
        t2 = Time.now
        info = [id58, os.to_s, display_name, name58, "#{src_file}:#{src_line}"].join(' - ')
        @@timings[info] = (t2 - t1)
      ensure
        puts $ERROR_INFO.message unless $ERROR_INFO.nil?
        id58_teardown
      end
    }
    name = "id='#{id58}'\nos=#{os}\n'#{name58}'"
    define_method(:"test_
#{name}", &execute_around)
  end

  Minitest.after_run do
    slow = @@timings.select { |_name, secs| secs > 0.000 }
    sorted = slow.sort_by { |_name, secs| -secs }.to_h
    size = sorted.size < 25 ? sorted.size : 25
    puts
    puts "Slowest #{size} tests are..." if size != 0
    sorted.each_with_index do |(name, secs), index|
      puts format('%3.4f - %-72s', secs, name)
      break if index == size
    end
    puts
  end

  ID58_ALPHABET = %w[
    0 1 2 3 4 5 6 7 8 9
    A B C D E F G H J K L M N P Q R S T U V W X Y Z
    a b c d e f g h j k l m n p q r s t u v w x y z
  ].join.freeze

  def self.id58?(str)
    str.is_a?(String) &&
      str.chars.all? { |char| ID58_ALPHABET.include?(char) }
  end

  def self.checked_id58(os, id58_suffix, lines)
    method = 'def self.id58_prefix'
    pointer = pling(' ' * method.index('.'))
    pointee = ['', pointer, method, '', ''].join("\n")
    pointer.prepend("\n\n")
    raise "#{pointer}missing#{pointee}" unless respond_to?(:id58_prefix)
    raise "#{pointer}empty#{pointee}" if id58_prefix == ''
    raise "#{pointer}not id58#{pointee}" unless id58?(id58_prefix)

    method = "test '#{id58_suffix}',"
    pointer = pling(' ' * method.index("'"))
    proposition = lines.join(space = ' ')
    pointee = ['', pointer, method, "'#{proposition}'", '', ''].join("\n")
    id58 = id58_prefix + id58_suffix
    pointer.prepend("\n\n")
    raise "#{pointer}empty#{pointee}" if id58_suffix == ''
    raise "#{pointer}not id58#{pointee}" unless id58?(id58_suffix)
    raise "#{pointer}duplicate#{pointee}" if seen?(id58, os)
    raise "#{pointer}overlap#{pointee}" if id58_prefix[-2..] == id58_suffix[0..1]

    seen(id58, os)
    id58
  end

  def self.pling(str)
    "#{str}!"
  end

  def self.seen?(id58, os)
    seen = @@seen_ids[id58] || []
    seen.include?(os)
  end

  def self.seen(id58, os)
    @@seen_ids[id58] ||= []
    @@seen_ids[id58] << os
  end

  def id58_setup; end

  def id58_teardown; end

  def os
    @_os
  end

  def display_name
    @_display_name
  end

  def id58
    @_id58
  end

  def name58
    @_name58
  end
end
