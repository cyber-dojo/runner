variable "service_name" {
  type    = string
  default = "runner"
}

variable "env" {
  type = string
}

variable "app_port" {
  type    = number
  default = 4597
}

variable "desired_count" {
  type    = number
  default = 3
}

variable "cpu_limit" {
  type    = number
  default = 20
}

variable "mem_limit" {
  type    = number
  default = 768
}

variable "mem_reservation" {
  type    = number
  default = 128
}

variable "container_restart_policy_enabled" {
  description = "Whether to enable restart policy for the container."
  type        = bool
  default     = true
}

variable "TAGGED_IMAGE" {
  type = string
}

# App variables
variable "app_env_vars" {
  type = map(any)
  default = {
    CYBER_DOJO_USE_CONTAINERD = "true"
    CYBER_DOJO_PROMETHEUS     = "false"
    CYBER_DOJO_RUNNER_PORT    = "4597"
  }
}

variable "ecr_replication_targets" {
  type    = list(map(string))
  default = []
}

variable "ecr_replication_origin" {
  type    = string
  default = ""
}
