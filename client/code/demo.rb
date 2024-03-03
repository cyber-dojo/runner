# frozen_string_literal: true
require_relative 'context'
require 'json'

class Demo
  def initialize
    @context = Context.new
  end

  def html
    @html =
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>runner demo</title>
        </head>
        <body style="padding:30px">
      HTML

    @html += '<h1>GET /alive</h1>'
    @html += pre(alive_snippet)
    @html += alive

    @html += '<h1>GET /ready</h1>'
    @html += pre(ready_snippet)
    @html += ready

    @html += '<h1>GET /sha</h1>'
    @html += pre(sha_snippet)
    @html += sha

    @html += '<h1>POST /run_cyber_dojo_sh</h1>'
    @html += pre(run_cyber_dojo_sh_snippet)
    @html += run_cyber_dojo_sh(gcc_assert_image_name)
    @html += run_cyber_dojo_sh('BAD/image_name')
    @html +=
      <<~HTML
        </body>
        </html>
      HTML
  end

  private

  def alive
    result, duration = timed { runner.alive? }
    boxed_pre(duration, result)
  end

  def alive_snippet
    [
      'alive = runner.alive?',
      'html = green(JSON.pretty_unparse(alive))'
    ].join("\n")
  end

  def ready
    result, duration = timed { runner.ready? }
    boxed_pre(duration, result)
  end

  def ready_snippet
    [
      'ready = runner.ready?',
      'html = green(JSON.pretty_unparse(ready))'
    ].join("\n")
  end

  def sha
    result, duration = timed { runner.sha }
    boxed_pre(duration, result)
  end

  def sha_snippet
    [
      'sha = runner.sha',
      'html = green(JSON.pretty_unparse(sha))'
    ].join("\n")
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

  def run_cyber_dojo_sh(image_name)
    files = gcc_assert_files
    manifest = {
      'image_name' => image_name,
      'max_seconds' => 10
    }
    _, duration = timed do
      @result = runner.run_cyber_dojo_sh(id: '729z65', files: files, manifest: manifest)
      @raised = false
    rescue StandardError => e
      @result = JSON.parse(e.message)
      @raised = true
    end
    css_colour = @raised ? 'LightGray' : 'LightGreen'
    boxed_pre(duration, @result, css_colour)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def gcc_assert_image_name
    gcc_assert_manifest['image_name']
  end

  def gcc_assert_files
    gcc_assert_manifest['visible_files'].transform_values do |file|
      file['content']
    end
  end

  def gcc_assert_manifest
    languages_start_points.manifest('C (gcc), assert')
  end

  def timed
    started = Time.now
    result = yield
    finished = Time.now
    duration = format('%.2f', (finished - started))
    [result, duration]
  end

  def pre(fragment)
    "<pre style='padding-left:30px;margin-left:30px'>#{fragment}</pre>"
  end

  def boxed_pre(duration, result, css_colour = 'LightGreen')
    border = 'border: 1px solid black;'
    padding = 'padding: 5px;'
    margin = 'margin-left: 30px; margin-right: 30px;'
    background = "background: #{css_colour};"
    whitespace = 'white-space: pre-wrap;'
    font = 'font-size:8pt;'
    "<pre style='#{whitespace}#{margin}#{border}#{padding}#{background}#{font}'>" +
      JSON.pretty_unparse(result).to_s +
      '</pre>' +
      "#{duration}s\n"
  end

  def languages_start_points
    @context.languages_start_points
  end

  def runner
    @context.runner
  end
end

$stdout.puts(Demo.new.html)
