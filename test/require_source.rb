# frozen_string_literal: true

def require_source(required)
  require_relative "../app/code/#{required}"
end
