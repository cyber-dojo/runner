
def require_code(required)
  require_relative "../source/#{required}"
end

def require_server_code(required)
  return unless ENV['CONTEXT'] == 'server'

  require_code(required)
end

# A file from source/server/lib, which holds what depends on no other file
# of this server.
def require_lib(required)
  require_code("lib/#{required}")
end

# The same, for a test that runs in both the client and the server.
def require_server_lib(required)
  require_server_code("lib/#{required}")
end
