# frozen_string_literal: true
require 'minitest/autorun'

class HexMiniTest < MiniTest::Test

  def initialize(arg)
    super(arg)
  end

  @@args = (ARGV.sort.uniq - ['--'])
  @@seen_hex_ids = []

  # - - - - - - - - - - - - - - - - - - - - - -

  def self.test(hex_suffix, *lines, &test_block)
    hex_id = checked_hex_id(hex_suffix, lines)
    if @@args === [] || @@args.any?{ |arg| hex_id.include?(arg) }
      hex_name = lines.join(space = ' ')
      name = "hex '#{hex_id}',\n'#{hex_name}'"
      execute_around = lambda {
        _hex_setup_caller(hex_id, hex_name)
        begin
          self.instance_eval(&test_block)
        ensure
          puts $!.message unless $!.nil?
          _hex_teardown_caller
        end
      }
      define_method("test_\n#{name}".to_sym, &execute_around)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def self.checked_hex_id(hex_suffix, lines)
    method = 'def self.hex_prefix'
    pointer = ' ' * method.index('.') + '!'
    pointee = (['',pointer,method,'','']).join("\n")
    pointer.prepend("\n\n")
    raise "#{pointer}missing#{pointee}" unless respond_to?(:hex_prefix)
    raise "#{pointer}empty#{pointee}" if hex_prefix === ''
    raise "#{pointer}not hex#{pointee}" unless hex_prefix =~ /^[0-9A-Fa-f]+$/

    method = "test '#{hex_suffix}',"
    pointer = ' ' * method.index("'") + '!'
    proposition = lines.join(space = ' ')
    pointee = ['',pointer,method,"'#{proposition}'",'',''].join("\n")
    hex_id = hex_prefix + hex_suffix
    pointer.prepend("\n\n")
    raise "#{pointer}empty#{pointee}" if hex_suffix === ''
    raise "#{pointer}not hex#{pointee}" unless hex_suffix =~ /^[0-9A-Fa-f]+$/
    raise "#{pointer}duplicate#{pointee}" if @@seen_hex_ids.include?(hex_id)
    raise "#{pointer}overlap#{pointee}" if hex_prefix[-2..-1] === hex_suffix[0..1]
    @@seen_hex_ids << hex_id
    hex_id
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def _hex_setup_caller(hex_id, hex_name)
    ENV['CYBER_DOJO_HEX_TEST_ID'] = hex_id
    @_hex_test_id = hex_id
    @_hex_test_name = hex_name
    hex_setup
  end

  def _hex_teardown_caller
    hex_teardown
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def hex_setup
  end

  def hex_teardown
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def hex_test_id
    @_hex_test_id
  end

  def hex_test_name
    @_hex_test_name
  end

end
