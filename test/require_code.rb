
def require_code(required)
  require_relative "../code/#{required}"
end

def require_server_code(required)
  if ENV['CONTEXT'] === 'server'
    require_code(required)
  end
end
