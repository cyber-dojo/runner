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
    sha
    ready?
    @image_name = 'cyberdojofoundation/gcc_assert'
    @id = '729z65'
    @files = gcc_assert_files
    @max_seconds = 10
    run_cyber_dojo_sh
    @image_name = 'BAD/image_name'
    run_cyber_dojo_sh
  end

  private

  def sha
    duration = timed { @result = runner.sha }
    fragment = [
      'sha = runner.sha',
      'html = green(JSON.pretty_unparse(sha))'
    ].join("\n")
    @html += pre(fragment, duration)
  end

  def ready?
    duration = timed { @result = runner.ready? }
    fragment = [
      'ready = runner.ready?',
      'html = green(JSON.pretty_unparse(ready))'
    ].join("\n")
    @html += pre(fragment, duration)
  end

  def run_cyber_dojo_sh
    raised = true
    duration = timed {
      args  = [ @image_name, @id, @files, @max_seconds ]
      begin
        @result = runner.run_cyber_dojo_sh(*args)
        raised = false
      rescue => error # ServiceError better RunnerError
        @result = JSON.parse(error.message)
      end
    }
    if raised
      fragment = [
        'begin',
        '  results = runner.run_cyber_dojo_sh(...)',
        '  ...',
        'rescue => error',
        '  json = JSON.parse(error.message)',
        '  html = gray(JSON.pretty_unparse(json))',
        'end'
      ].join("\n")
      @html += pre(fragment, duration, 'LightGray')
    else
      fragment = [
        'results = runner.run_cyber_dojo_sh(...)',
        'html = green(JSON.pretty_unparse(results))'
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

  def gcc_assert_files
    {
      'hiker.c'       => read('hiker.c'),
      'hiker.h'       => read('hiker.h'),
      'hiker.tests.c' => read('hiker.tests.c'),
      'cyber-dojo.sh' => read('cyber-dojo.sh'),
      'makefile'      => read('makefile')
    }
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
