# frozen_string_literal: true
def require_code(required)
  require_relative "../code/#{required}"
end

def require_server_code(required)
  return unless ENV['CONTEXT'] === 'server'

  require_code(required)
end
