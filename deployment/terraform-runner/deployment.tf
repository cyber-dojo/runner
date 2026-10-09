module "ecs-service" {
  source                           = "s3::https://s3-eu-central-1.amazonaws.com/terraform-modules-9d7e951c290ec5bbe6506e0ddb064808764bc636/terraform-modules.zip//ecs-service/v5"
  service_name                     = var.service_name
  TAGGED_IMAGE                     = var.TAGGED_IMAGE
  enable_execute_command           = "true"
  app_port                         = var.app_port
  desired_count                    = var.desired_count
  cpu_limit                        = var.cpu_limit
  mem_reservation                  = var.mem_reservation
  mem_limit                        = var.mem_limit
  app_env_vars                     = local.app_env_vars
  ecs_wait_for_steady_state        = true
  ecs_service_update_timeout       = "10m"
  container_restart_policy_enabled = var.container_restart_policy_enabled
  volumes = [
    {
      name          = "docker_socket"
      containerPath = "/var/run/docker.sock"
      host_path     = "/var/run/docker.sock"
    },
    # One store of spares for every task on the host, as the spares are
    # containers on the host's one daemon. /dev/shm is a tmpfs, so the store
    # goes when the kernel whose clock its expiries were read from goes.
    {
      name          = "spares"
      containerPath = "/tmp/cyber_dojo_spares"
      host_path     = "/dev/shm/cyber_dojo_runner_spares"
    }
  ]
  tags = module.tags.result
}
