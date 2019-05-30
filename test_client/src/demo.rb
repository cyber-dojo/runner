require_relative 'runner_service'
require 'json'

class Demo

  def call(_env)
    inner_call
    [ 200, text_html_content, [ @html ] ]
  rescue => error
    body = [ [error.message] + [error.backtrace] ]
    [ 400, text_html_content, body ]
    #pre('exception', 0.0, 'blue', body)
  end

  def text_html_content
    { 'Content-Type' => 'text/html' }
  end

  def inner_call
    @html = ''
    @image_name = 'cyberdojofoundation/gcc_assert'
    @id = '729z65'
    @files = starting_files
    sha
    ready?
    change(hiker_c.sub('6 * 9', '6 * 9'))
    run_cyber_dojo_sh('Red')
    change(hiker_c.sub('6 * 9', 'syntax-error'))
    run_cyber_dojo_sh('Yellow')
    change(hiker_c.sub('6 * 9', '6 * 7'))
    run_cyber_dojo_sh('Green')
    change(hiker_c.sub('return', "for(;;);\n return"))
    run_cyber_dojo_sh('LightGray', 3)
    #change(42)
    #run_cyber_dojo_sh('LightGray', 3)
  end

  private

  def change(content)
    @files['hiker.c'] = content
  end

  def sha
    duration = timed { @result = runner.sha }
    @html += pre('sha', duration, 'white')
  end

  def ready?
    duration = timed { @result = runner.ready? }
    @html += pre('ready?', duration, 'white')
  end

  def run_cyber_dojo_sh(css_colour, max_seconds = 10)
    args  = [ @image_name, @id, @files, max_seconds ]
    duration = timed { @result = runner.run_cyber_dojo_sh(*args) }
    @html += pre('run_cyber_dojo_sh', duration, css_colour)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def runner
    RunnerService.new
  end

  def timed
    started = Time.now
    yield
    finished = Time.now
    '%.2f' % (finished - started)
  end

  def starting_files
    {
      'hiker.c'       => hiker_c,
      'hiker.h'       => read('hiker.h'),
      'hiker.tests.c' => read('hiker.tests.c'),
      'cyber-dojo.sh' => read('cyber-dojo.sh'),
      'makefile'      => read('makefile')
    }
  end

  def file(filename)
    { filename => read(filename) }
  end

  def hiker_c
    read('hiker.c')
  end

  def read(filename)
    IO.read("/app/test/start_files/C_assert/#{filename}")
  end

  def pre(name, duration, colour)
    border = 'border: 1px solid black;'
    padding = 'padding: 5px;'
    margin = 'margin-left: 30px; margin-right: 30px;'
    background = "background: #{colour};"
    whitespace = "white-space: pre-wrap;"
    "<pre style='margin-left:30px'>/#{name}(#{duration}s)</pre>" +
    "<pre style='#{whitespace}#{margin}#{border}#{padding}#{background}'>" +
      "#{JSON.pretty_unparse(@result)}" +
    '</pre>'
  end

end
