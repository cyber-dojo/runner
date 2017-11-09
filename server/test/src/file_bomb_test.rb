require_relative 'test_base'

class FileBombTest < TestBase

  def self.hex_prefix
    '1988B'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'DB3',
  %w( file-bomb in C to exhaust file-handles fails to go off ) do
    filename = (os == :Alpine ? 'hiker.c' : 'hiker.cpp')
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { filename => c_file_bomb }
      })
    }
    assert seen?('All tests passed'), quad
    assert seen?('fopen() != NULL'), quad
    assert seen?('fopen() == NULL'), quad
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def seen?(text)
    count = 0
    (stdout+stderr).split("\n").each { |line|
      if line.include?(text)
        count += 1
      end
    }
    count
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def c_file_bomb
    [
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
