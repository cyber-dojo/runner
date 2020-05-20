# frozen_string_literal: true

class ProcessDecorator
  
  def initialize(decorated, options)
    @decorated = decorated
    @options = options
  end

  def method_missing(name, *args, &block)
    return unless @decorated.respond_to?(name)
    if @options.has_key?(name)
      @options[name].call(*args)
    else
      @decorated.public_send(name, *args, &block)
    end
  end

end
