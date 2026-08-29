require_relative 'cyber_dojo_sh_host_config'
require_relative 'sandbox'

# The body of the POST /containers/create that runs one cyber-dojo.sh, saying
# everything the docker CLI would otherwise be told in flags. Every entry
# arrives the same way: as a group of keys merged in by the method that
# explains it.
module CyberDojoShContainerConfig
  def self.create_config(id, image_name)
    [
      image(image_name),
      cyber_dojo_sh_command,
      sandbox_user,
      env(id, image_name),
      stdio,
      host_config(image_name)
    ].reduce(:merge)
  end

  # The image to run, with its own entrypoint dropped so that the command is
  # what runs.
  def self.image(image_name)
    {
      'Image' => image_name,
      'Entrypoint' => []
    }
  end
  private_class_method :image

  # Unpacks the incoming files, then hands over to the script that runs the
  # kata's cyber-dojo.sh and sends the payload back on stdout.
  def self.cyber_dojo_sh_command
    { 'Cmd' => ['bash', '-c', 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'] }
  end
  private_class_method :cyber_dojo_sh_command

  # Never root.
  def self.sandbox_user
    { 'User' => "#{Sandbox::UID}:#{Sandbox::GID}" }
  end
  private_class_method :sandbox_user

  # What the container knows about the run it is serving.
  def self.env(id, image_name)
    { 'Env' => [image_name_var(image_name), sandbox_var, id_var(id)] }
  end
  private_class_method :env

  # Names the image the kata is running under.
  def self.image_name_var(image_name)
    "CYBER_DOJO_IMAGE_NAME=#{image_name}"
  end
  private_class_method :image_name_var

  # Names the run, for tracing.
  def self.id_var(id)
    "CYBER_DOJO_ID=#{id}"
  end
  private_class_method :id_var

  # Names the dir the kata's files are unpacked into.
  def self.sandbox_var
    "CYBER_DOJO_SANDBOX=#{Sandbox::DIR}"
  end
  private_class_method :sandbox_var

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
