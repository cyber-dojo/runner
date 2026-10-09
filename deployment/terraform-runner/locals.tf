locals {
  app_env_vars = [
    for key, value in merge(var.app_env_vars, { CYBER_DOJO_RUNNER_SPARES_PER_NODE = var.spares_per_node }) : {
      name  = key
      value = value
    }
  ]
}
