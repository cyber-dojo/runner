require_relative 'runner_service'
require 'json'

class Demo

  def call(_env)
    inner_call
    [ 200, text_html_content, [ @html ] ]
  rescue => error
    [ 400, text_html_content, [ [error.message] + [error.backtrace] ] ]
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
    run_cyber_dojo_sh
    @image_name = 'BAD/image_name'
    run_cyber_dojo_sh
  end

  private

  def change(content)
    @files['hiker.c'] = content
  end

  def sha
    duration = timed { @result = runner.sha }
    fragment = [
      'sha = runner.sha',
      'html = JSON.pretty_unparse(sha)'
    ].join("\n")
    @html += pre(fragment, duration)
  end

  def ready?
    duration = timed { @result = runner.ready? }
    fragment = [
      'ready = runner.ready?',
      'html = JSON.pretty_unparse(ready)'
    ].join("\n")
    @html += pre(fragment, duration)
  end

  def run_cyber_dojo_sh
    raised = true
    duration = timed {
      args  = [ @image_name, @id, @files, 10 ]
      begin
        @result = runner.run_cyber_dojo_sh(*args)
        raised = false
      rescue => error
        @result = JSON.parse(error.message)
      end
    }
    if raised
      fragment = [
        'begin',
        '  results = runner.run_cyber_dojo_sh(...)',
        '  ...',
        'rescue => error',
        '  html = JSON.parse(error.message)',
        'end'
      ].join("\n")
      @html += pre(fragment, duration, 'LightGray')
    else
      fragment = [
        'results = runner.run_cyber_dojo_sh(...)',
        'html = JSON.pretty_unparse(results)'
      ].join("\n")
      @html += pre(fragment, duration)
    end
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

  def pre(fragment, duration, colour = 'LightGreen')
    border = 'border: 1px solid black;'
    padding = 'padding: 5px;'
    margin = 'margin-left: 30px; margin-right: 30px;'
    background = "background: #{colour};"
    whitespace = "white-space: pre-wrap;"
    "<pre style='margin-left:30px'>#{duration}s\n#{fragment}</pre>" +
    "<pre style='#{whitespace}#{margin}#{border}#{padding}#{background}'>" +
      "#{JSON.pretty_unparse(@result)}" +
    '</pre>'
  end

end
