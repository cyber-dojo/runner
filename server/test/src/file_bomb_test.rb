require_relative 'test_base'

class FileBombTest < TestBase

  def self.hex_prefix
    '1988B'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DB3',
  %w( [Alpine] file-bomb in C to exhaust file-handles fails to go off ) do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => c_file_bomb }
      })
    }
    assert_colour 'green'
    assert_stderr ''
    lines = stdout.split("\n")
    assert_equal 1, lines.count{ |line| line == 'All tests passed' }
    assert lines.count{ |line| line.start_with? 'fopen() != NULL' } > 42
    assert_equal 1, lines.count{ |line| line.start_with? 'fopen() == NULL' }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def c_file_bomb
    [
      '#include "hiker.h"',
      '#include <stdio.h>',
      '',
      'int answer(void)',
      '{',
      '  for (int i = 0;;i++)',
      '  {',
      '    char filename[42];',
      '    sprintf(filename, "wibble%d.txt", i);',
      '    FILE * f = fopen(filename, "w");',
      '    if (f)',
      '      fprintf(stdout, "fopen() != NULL %s\n", filename);',
      '    else',
      '    {',
      '      fprintf(stdout, "fopen() == NULL %s\n", filename);',
      '      break;',
      '    }',
      '  }',
      '  return 6 * 7;',
      '}'
    ].join("\n")
  end

end
