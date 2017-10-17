require_relative 'runner_service'
require 'sinatra'
require 'sinatra/base'

class Demo < Sinatra::Base

  get '/' do
    html = ''

    duration = timed { @quad = run(files) }
    html += pre(duration, @quad, 'Red')

    files['hiker.c'] = 'sdsdsdsd'
    duration = timed { @quad = run(files) }
    html += pre(duration, @quad, 'Yellow')

    files['hiker.c'] = hiker_c.sub('6 * 9', '6 * 7')
    duration = timed { @quad = run(files) }
    html += pre(duration, @quad, 'Lime')

    files['hiker.c'] = hiker_c.sub('return', "for(;;);\n    return")
    duration = timed { @quad = run(files, 3) }
    html += pre(duration, @quad, 'LightGray')

    "<div style='font-size:0.5em'>#{html}</div>"
  end

  private

  def files
    @files ||= {
      'hiker.c'       => hiker_c,
      'hiker.h'       => read('hiker.h'),
      'hiker.tests.c' => read('hiker.tests.c'),
      'cyber-dojo.sh' => read('cyber-dojo.sh'),
      'makefile'      => read('makefile')
    }
  end

  def hiker_c
    read('hiker.c')
  end

  def image_name
    'cyberdojofoundation/gcc_assert'
  end

  def kata_id
    '729B652756'
  end

  def avatar_name
    'salmon'
  end

  def run(visible_files, max_seconds=10)
    runner.run(image_name, kata_id, avatar_name, visible_files, max_seconds)
  end

  def runner
    RunnerService.new
  end

  def read(filename)
    IO.read("/app/test/start_files/gcc_assert/#{filename}")
  end

  def timed
    started = Time.now
    yield
    finished = Time.now
    '%.2f' % (finished - started)
  end

  def pre(duration, quad, css_colour = 'white')
    border = 'border:1px solid black'
    padding = 'padding:10px'
    background = "background:#{css_colour}"
    "<pre>/run(#{duration}s)</pre>" +
    "<pre style='#{border};#{padding};#{background}'>" +
    "#{JSON.pretty_unparse(quad)}" +
    '</pre>'
  end

end


