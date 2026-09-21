require_relative '../test_base'

class FileTruncationTest < TestBase

  multi_os_test 'E4A52A', %w(
  | generated text files bigger than 50K are truncated
  ) do
    set_context
    filename = 'large_file.txt'
    script = "od -An -x /dev/urandom | head -c#{51 * 1024} > #{filename}"
    script += ';'
    script += "stat -c%s #{filename}"

    assert_cyber_dojo_sh(script)

    assert_equal "#{51 * 1024}\n", stdout, :stdout_size
    assert_equal [filename], created.keys
    assert created[filename]['truncated'].is_a?(TrueClass), :truncated
    assert_equal 50 * 1024, created[filename]['content'].size, :size
    assert_equal({}, changed, :changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E4A52B', %w(
  | stdout and stderr are truncated to 50K
  ) do
    set_context
    script = [
      "od -An -x /dev/urandom | head -c#{51 * 1024} > /tmp/stdout",
      "od -An -x /dev/urandom | head -c#{51 * 1024} > /tmp/stderr",
      'cat /tmp/stdout',
      '1>&2 cat /tmp/stderr'
    ].join(';')

    assert_cyber_dojo_sh(script)

    assert_equal 50 * 1024, stdout.size, :stdout_content_is_truncated
    assert run_result['stdout']['truncated'].is_a?(TrueClass), :stdout_truncated_property_is_true
    assert_equal 50 * 1024, stderr.size, :stderr_content_is_truncated
    assert run_result['stderr']['truncated'].is_a?(TrueClass), :stderr_truncated_property_is_true
  end

  # - - - - - - - - - - - - - - - - -

  test 'E4A52C', %w(
  | stdout of multi-byte characters is truncated by bytes, and says it was
  ) do
    set_context

    assert_cyber_dojo_sh(euro_script(EUROS))

    assert run_result['stdout']['truncated'].is_a?(TrueClass), :stdout_truncated_property_is_true
    assert_equal KEPT_EUROS, stdout.size, :stdout_character_count
  end

  # - - - - - - - - - - - - - - - - -

  test 'E4A52D', %w(
  | a generated file of multi-byte characters is truncated by bytes,
  | and says it was
  ) do
    set_context
    filename = 'euros.txt'

    assert_cyber_dojo_sh("#{euro_script(EUROS)} > #{filename}")

    assert created[filename]['truncated'].is_a?(TrueClass), :truncated
    assert_equal KEPT_EUROS, created[filename]['content'].size, :character_count
  end

  private

  # The euro sign is three UTF-8 bytes, which is what tells a byte count from
  # a character count. 20_000 of them is 60_000 bytes, comfortably over the
  # 51_200 limit, while being only 20_000 characters - under it. A run that
  # counted characters would call this untruncated.
  EUROS = 20_000

  # 51_200 bytes is 17_066 whole euro signs and two bytes of a seventeenth.
  # Those two are an incomplete character, which Utf8.clean drops.
  KEPT_EUROS = 17_066

  # Written as octal bytes so this file stays ASCII, and built by repeating a
  # whole character so the count is exact rather than cut at a byte offset.
  def euro_script(count)
    [
      "EURO=$(printf '\\342\\202\\254')",
      %(yes "${EURO}" | head -n #{count} | tr -d '\\n')
    ].join(';')
  end
end
