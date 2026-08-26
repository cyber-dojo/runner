require_relative 'cyber_dojo_sh_host_config'
require_relative 'sandbox'

# The body of a POST /containers/create for one run of cyber-dojo.sh, saying
# everything the docker CLI would otherwise be told in flags. Every entry
# arrives the same way: as a group of keys merged in by the method that
# explains it.
module CyberDojoShContainerConfig
  def self.create_config(id, image_name)
    [
      image_and_command(image_name),
      sandbox_user,
      env(id, image_name),
      stdio,
      host_config(image_name)
    ].reduce(:merge)
  end

  # Unpacks the incoming files, then hands over to the script that runs the
  # kata's cyber-dojo.sh and sends the payload back on stdout. The image's own
  # entrypoint is dropped so that the command is what runs.
  BODY = 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'.freeze

  def self.image_and_command(image_name)
    {
      'Image' => image_name,
      'Cmd' => ['bash', '-c', BODY],
      'Entrypoint' => []
    }
  end
  private_class_method :image_and_command

  # Never root.
  def self.sandbox_user
    { 'User' => "#{Sandbox::UID}:#{Sandbox::GID}" }
  end
  private_class_method :sandbox_user

  # What the run tells cyber_dojo_main.sh about itself.
  def self.env(id, image_name)
    {
      'Env' => [
        "CYBER_DOJO_IMAGE_NAME=#{image_name}",
        "CYBER_DOJO_ID=#{id}",
        "CYBER_DOJO_SANDBOX=#{Sandbox::DIR}"
      ]
    }
  end
  private_class_method :env

  # The tgz goes in on stdin, and the payload comes back on stdout. Closing
  # stdin once is what gives the container's [tar -zxf -] its end of file.
  # There is no tty: a pty translates the payload bytes and truncates the
  # stream. See docker_attach_frames.rb
  def self.stdio
    {
      'OpenStdin' => true,
      'StdinOnce' => true,
      'AttachStdin' => true,
      'AttachStdout' => true,
      'AttachStderr' => true,
      'Tty' => false
    }
  end
  private_class_method :stdio

  # What the daemon does around the container rather than inside it.
  def self.host_config(image_name)
    CyberDojoShHostConfig.config(image_name)
  end
  private_class_method :host_config
end
