# frozen_string_literal: true

def require_source(required)
  require_relative "../runner/source/#{required}"
end

def require_server_source(required)
  if ENV['CONTEXT'] === 'server'
    require_source(required)
  end
end
