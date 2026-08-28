require_relative 'cyber_dojo_sh_host_config'
require_relative 'sandbox'

# The bodies of the docker API calls that run one cyber-dojo.sh, saying
# everything the docker CLI would otherwise be told in flags. Every entry
# arrives the same way: as a group of keys merged in by the method that
# explains it.
#
# The keys divide by what they depend on. image_config is all a container can
# be created from knowing only its image, and exec_config is what one
# test-run adds to a container that already exists.
module CyberDojoShContainerConfig
  # The body of a POST /containers/create for a container made before the run
  # it will serve is known. It sleeps instead of running the kata, so that it
  # is still there to be exec'd into, and it holds no stdin, because the tgz
  # arrives on the exec's stdin instead.
  def self.image_config(image_name)
    [
      image(image_name),
      sleeping_command,
      sandbox_user,
      image_env(image_name),
      host_config(image_name)
    ].reduce(:merge)
  end

  # The body of a POST /containers/{id}/exec for one run of cyber-dojo.sh:
  # what that run adds to a container image_config already made.
  def self.exec_config(id)
    [
      cyber_dojo_sh_command,
      run_env(id),
      exec_stdio
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

  # Does nothing, for long enough to be exec'd into. runner.rb caps a run at
  # 15 seconds, so a minute outlasts any run and the grace its stop allows,
  # while still bounding how long a container nobody wants can survive.
  def self.sleeping_command
    { 'Cmd' => %w[sleep 60] }
  end
  private_class_method :sleeping_command

  # Never root.
  def self.sandbox_user
    { 'User' => "#{Sandbox::UID}:#{Sandbox::GID}" }
  end
  private_class_method :sandbox_user

  # What a container knows about the run from its image alone.
  def self.image_env(image_name)
    { 'Env' => [image_name_var(image_name), sandbox_var] }
  end
  private_class_method :image_env

  # What only the run knows. Exec honours Env, which is how this reaches a
  # container created before it.
  def self.run_env(id)
    { 'Env' => [id_var(id)] }
  end
  private_class_method :run_env

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

  # The tgz goes in on the exec's stdin, and the payload comes back on its
  # stdout. Shutting that stdin down once is what gives the container's
  # [tar -zxf -] its end of file. There is no tty: a pty translates the payload
  # bytes and truncates the stream. See docker_attach_frames.rb
  def self.exec_stdio
    {
      'AttachStdin' => true,
      'AttachStdout' => true,
      'AttachStderr' => true,
      'Tty' => false
    }
  end
  private_class_method :exec_stdio

  # What the daemon does around the container rather than inside it.
  def self.host_config(image_name)
    CyberDojoShHostConfig.config(image_name)
  end
  private_class_method :host_config
end
