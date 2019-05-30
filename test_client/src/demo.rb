require_relative 'runner_service'
require 'json'

class Demo

  def call(_env)
    inner_call
    [ 200, content_text_html, [ @html ] ]
  rescue => error
    [ 400, content_text_html, [ [error.message] + [error.backtrace] ] ]
  end

  def inner_call
    @html = ''
    @html += '<h1>sha</h1>'
    @html += pre(sha_snippet)
    sha
    @html += '<h1>ready?</h1>'
    @html += pre(ready_snippet)
    ready?
    @html += '<h1>run_cyber_dojo_sh</h1>'    
    @html += pre(run_cyber_dojo_sh_snippet)
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
    @html += boxed_pre(duration, @result)
  end

  def sha_snippet
    [
      'sha = runner.sha',
      'html = green(JSON.pretty_unparse(sha))'
    ].join("\n")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def ready?
    duration = timed { @result = runner.ready? }
    @html += boxed_pre(duration, @result)
  end

  def ready_snippet
    [
      'ready = runner.ready?',
      'html = green(JSON.pretty_unparse(ready))'
    ].join("\n")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh
    duration = timed {
      args  = [ @image_name, @id, @files, @max_seconds ]
      begin
        @result = runner.run_cyber_dojo_sh(*args)
        @raised = false
      rescue => error # ServiceError better RunnerError
        @result = JSON.parse(error.message)
        @raised = true
      end
    }
    css_colour = @raised ? 'LightGray' : 'LightGreen'
    @html += boxed_pre(duration, @result, css_colour)
  end

  def run_cyber_dojo_sh_snippet
    [
      'begin',
      '  result = runner.run_cyber_dojo_sh(...)',
      '  html = green(JSON.pretty_unparse(result))',
      'rescue => error',
      '  json = JSON.parse(error.message)',
      '  html = gray(JSON.pretty_unparse(json))',
      'end'
    ].join("\n")
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

  def pre(fragment)
    "<pre style='margin-left:30px'>#{fragment}</pre>"
  end

  def boxed_pre(duration, result, css_colour = 'LightGreen')
    border = 'border: 1px solid black;'
    padding = 'padding: 5px;'
    margin = 'margin-left: 30px; margin-right: 30px;'
    background = "background: #{css_colour};"
    whitespace = "white-space: pre-wrap;"
    font = 'font-size:8pt;'
    "<pre style='#{whitespace}#{margin}#{border}#{padding}#{background}#{font}'>" +
      "#{duration}s\n" +
      "#{JSON.pretty_unparse(result)}" +
    '</pre>'
  end

  def content_text_html
    { 'Content-Type' => 'text/html' }
  end

end
