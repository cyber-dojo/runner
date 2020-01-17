
# It's useful to keep these tolerances quite close
# to their limit. It helps to show large jumps which
# can be a sign of too much work in progres.

def table
  [
    [ 'tests',                  test_count,     '!=',   0 ],
    [ 'failures',               failure_count,  '==',   0 ],
    [ 'errors',                 error_count,    '==',   0 ],
    [ 'warnings',               warning_count,  '==',   0 ],
    [ 'skips',                  skip_count,     '==',   0 ],
    [ 'duration(test)[s]',      test_duration,  '<=', 240 ],
    [ 'coverage(app)[%]',       app_coverage,   '==', 100 ],
    [ 'coverage(test)[%]',      test_coverage,  '==', 100 ],
    [ 'lines(test)/lines(app)', f2(line_ratio), '>=', 2.9 ],
    [ 'hits(app)/hits(test)',   f2(hits_ratio), '>=', 6.4 ],
  ]
end

def number
  '[\.|\d]+'
end

def f2(s)
  result = ("%.2f" % s).to_s
  result += '0' if result.end_with?('.0')
  result
end

def cleaned(s)
  # guard against invalid byte sequence
  s = s.encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
  s = s.encode('UTF-8', 'UTF-16')
end

def coloured(tf)
  red = 31
  green = 32
  colourize(tf ? green : red, tf)
end

def colourize(code, word)
  "\e[#{code}m#{word}\e[0m"
end

def get_index_stats(name)
  html = `cat #{ARGV[1]}`
  html = cleaned(html)
  # It would be nice if simplecov saved the raw data to a json file
  # and created the html from that, but alas it does not.
  pattern = /<div class=\"file_list_container\" id=\"#{name}\">
  \s*<h2>\s*<span class=\"group_name\">#{name}<\/span>
  \s*\(<span class=\"covered_percent\"><span class=\"\w+\">([\d\.]*)\%<\/span><\/span>
  \s*covered at
  \s*<span class=\"covered_strength\">
  \s*<span class=\"\w+\">
  \s*(#{number})
  \s*<\/span>
  \s*<\/span> hits\/line\)
  \s*<\/h2>
  \s*<a name=\"#{name}\"><\/a>
  \s*<div>
  \s*<b>#{number}<\/b> files in total.
  \s*<b>(#{number})<\/b> relevant lines./m
  r = html.match(pattern)
  {
    :coverage      => f2(r[1]),
    :hits_per_line => f2(r[2]),
    :line_count    => r[3].to_i,
    :name          => name
  }
end

# - - - - - - - - - - - - - - - - - - - - - - -

def get_test_log_stats
  test_log = `cat #{ARGV[0]}`
  test_log = cleaned(test_log)

  stats = {}

  warning_regex = /: warning:/m
  stats[:warning_count] = test_log.scan(warning_regex).size

  finished_pattern = "Finished in (#{number})s, (#{number}) runs/s"
  m = test_log.match(Regexp.new(finished_pattern))
  stats[:time]               = f2(m[1])
  stats[:tests_per_sec]      = m[2].to_i

  summary_pattern = %w(runs assertions failures errors skips).map{ |s| "(#{number}) #{s}" }.join(', ')
  m = test_log.match(Regexp.new(summary_pattern))
  stats[:test_count]      = m[1].to_i
  stats[:assertion_count] = m[2].to_i
  stats[:failure_count]   = m[3].to_i
  stats[:error_count]     = m[4].to_i
  stats[:skip_count]      = m[5].to_i

  stats
end

# - - - - - - - - - - - - - - - - - - - - - - -

def log_stats
  $log_stats ||= get_test_log_stats
end

def test_stats
  $test_stats ||= get_index_stats('test')
end

def app_stats
  $app_stats ||= get_index_stats('app')
end

# - - - - - - - - - - - - - - - - - - - - - - -

def test_count;    log_stats[:test_count]; end
def failure_count; log_stats[:failure_count]; end
def error_count;   log_stats[:error_count]; end
def warning_count; log_stats[:warning_count]; end
def skip_count;    log_stats[:skip_count]; end
def test_duration; log_stats[:time].to_f; end

def app_coverage;  app_stats[:coverage].to_f; end
def test_coverage; test_stats[:coverage].to_f; end

def line_ratio; (test_stats[:line_count].to_f / app_stats[:line_count].to_f); end
def hits_ratio; (app_stats[:hits_per_line].to_f / test_stats[:hits_per_line].to_f); end

# - - - - - - - - - - - - - - - - - - - - - - -

done = []
puts
table.each do |name,value,op,limit|
  result = eval("#{value} #{op} #{limit}")
  puts "%s | %s %s %s | %s" % [
    name.rjust(25), value.to_s.rjust(7), op, limit.to_s.rjust(5), coloured(result)
  ]
  done << result
end
puts
exit done.all?
