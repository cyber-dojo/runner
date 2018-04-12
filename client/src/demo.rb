require_relative 'runner_service'

class Demo

  def call(_env)
    @html = ''
    in_kata {
      as('salmon') {
        red
        amber
        green
        time_out
      }
    }
    [ 200, { 'Content-Type' => 'text/html' }, [ @html ] ]
  end

  private

  def in_kata
    @image_name = 'cyberdojofoundation/gcc_assert'
    @kata_id = '729B652756'
    duration = timed {
      runner.kata_new(image_name, kata_id)
    }
    @html += pre('kata_new', duration)
    begin
      yield
    ensure
      duration = timed {
        runner.kata_old(image_name, kata_id)
      }
      @html += pre('kata_old', duration)
    end
  end

  attr_reader :image_name, :kata_id

  # - - - - - - - - - - - - - - - - - - - - -

  def as(avatar_name)
    @avatar_name = avatar_name
    @new_files = starting_files
    @deleted_files = {}
    @changed_files = {}
    duration = timed {
      runner.avatar_new(image_name, kata_id, avatar_name, new_files)
      @unchanged_files = new_files
      @new_files = {}
    }
    @html += pre('avatar_new', duration)
    begin
      yield
    ensure
      duration = timed {
        runner.avatar_old(image_name, kata_id, avatar_name)
      }
      @html += pre('avatar_old', duration)
    end
  end

  attr_reader :avatar_name
  attr_reader :new_files, :deleted_files, :unchanged_files, :changed_files

  # - - - - - - - - - - - - - - - - - - - - -

  def red
    run_cyber_dojo_sh('Red')
  end

  def amber
    change('hiker.c', hiker_c.sub('6 * 9', 'syntax-error'))
    run_cyber_dojo_sh('Yellow')
  end

  def green
    change('hiker.c', hiker_c.sub('6 * 9', '6 * 7'))
    run_cyber_dojo_sh('Green')
  end

  def time_out
    change('hiker.c', hiker_c.sub('return', "for(;;);\n return"))
    run_cyber_dojo_sh('LightGray', 3)
  end

  def change(filename, content)
    changed_files[filename] = content
    unchanged_files.delete(filename)
  end

  def run_cyber_dojo_sh(colour, max_seconds = 10)
    result = nil
    args  = [ image_name, kata_id, avatar_name ]
    args += [ new_files, deleted_files, unchanged_files, changed_files ]
    args << max_seconds
    duration = timed {
      result = runner.run_cyber_dojo_sh(*args)
    }
    @html += pre('run_cyber_dojo_sh', duration, colour, result)
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

  def hiker_c
    read('hiker.c')
  end

  def read(filename)
    IO.read("/app/test/start_files/Alpine/#{filename}")
  end

  def pre(name, duration, colour = 'white', result = nil)
    border = 'border: 1px solid black;'
    padding = 'padding: 5px;'
    margin = 'margin-left: 30px; margin-right: 30px;'
    background = "background: #{colour};"
    whitespace = "white-space: pre-wrap;"
    html = "<pre>/#{name}(#{duration}s)</pre>"
    unless result.nil?
      html += "<pre style='#{whitespace}#{margin}#{border}#{padding}#{background}'>" +
              "#{JSON.pretty_unparse(result)}" +
              '</pre>'
    end
    html
  end

end
