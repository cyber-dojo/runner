require_relative 'nearest_ancestors'

class RaggerService

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent

  def colour(image_name, stdout, stderr, status)
    # TODO: probe the container to see if rag.rb file is in
    # specific location. If it is, use it to determine
    # colour of traffic-light. For now, faking it
    # which is why image_name is being passed as 1st arg
    # instead of the container's id
    if image_name == "#{cdf}/gcc_assert"
      src = gcc_assert.join("\n")
      rag = eval(src)
      return rag.call(stdout, stderr, status).to_s
    else
      nil
    end
  end

  private

  include NearestAncestors
  def shell; nearest_ancestors(:shell); end

  def cdf; 'cyberdojofoundation'; end

  def gcc_assert
    [ 'lambda { |stdout, stderr, status|',
      '  output = stdout + stderr',
      '  return :red   if /(.*)Assertion(.*)failed./.match(output)',
      '  return :green if /(All|\d+) tests passed/.match(output)',
      '  return :amber',
      '}'
    ]
  end

end
