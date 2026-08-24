require 'simplecov'
require 'json'

# A SimpleCov formatter writing coverage_metrics.json, which holds the per-group
# line and branch totals that check_test_metrics.rb, bin/check_coverage.sh and
# bin/run_tests.sh read. SimpleCov ships its own JSON formatter, writing
# coverage.json shaped per file, so this one carries its own name rather than
# reopening that class and redefining its format method.
#
# based on https://github.com/vicentllongo/simplecov-json
class CoverageMetricsFormatter
  def format(result)
    data = {
      timestamp: result.created_at.to_i,
      command_name: result.command_name
    }
    result.groups.each do |name, file_list|
      next if name == 'Ungrouped'

      data[name] = {
        lines: {
          total: file_list.lines_of_code,
          covered: file_list.covered_lines,
          missed: file_list.missed_lines
        },
        branches: {
          total: file_list.total_branches,
          covered: file_list.covered_branches,
          missed: file_list.missed_branches
        }
      }
    end
    File.open(output_filepath, 'w+') do |file|
      file.print(JSON.pretty_generate(data))
    end
    puts output_message(result)
    puts "SimpleCov version #{version}"
    data.to_json
  end

  def output_filepath
    File.join(output_path, output_filename)
  end

  def output_filename
    'coverage_metrics.json'
  end

  def output_message(result)
    "Coverage report generated for #{result.command_name} to #{output_filepath}. #{result.covered_lines} / #{result.total_lines} LOC (#{result.covered_percent.round(2)}%) covered."
  end

  private

  def output_path
    SimpleCov.coverage_path
  end

  def version
    SimpleCov::VERSION
  end
end
