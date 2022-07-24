variable "image" {
  default = "redis:3.1"
}

variable "job_gen_spec" {
  description = "defines the values to create unique job names combining prefix-app-name-suffix"
  type        = object({
    prefix   = list(string)
    suffix   = list(string)
    app_name = string

  })
  default = {
    prefix   = ["pod01", "pod02"]
    suffix   = ["grp1", "grp2"]
    app_name = "app"
  }
}

variable "job_name_prefix" {
  description = "list of all job prefixes to create jobs for"
  type        = list(string)
  default     = ["region1", "region2"]
}
variable "job_name_suffixes" {
  description = "list of all job suffixes to create jobs for"
  type        = list(string)
  default     = ["grp1", "grp2"]

}
variable "job_name_base" {
  default = "app"
  type    = string
}
variable "driver" {
  description = "needs to be part of the task configuration"
  type        = string
  default     = "docker"
}

variable "group_specs" {
  description = "specifies group generation without the nomad template"
  type        = list(object({
    group_label = string
    tags        = number
    #    task_specs = list(object({}))
  }))
  default = [
    {
      group_label = "api"
      tags        = 80
    },
    {
      group_label = "ui"
      tags        = 8080
    },
    {
      group_label = "batman"
      tags        = 8080
    }
  ]
}

variable "namespace" {
  description = "namespace to deploy into"
  default     = "default"
  type        = string
}

variable "template_name" {
  description = "choose which template to choose as the base"
  default     = "jobspec.nomad"
  type        = string
}

#variable "task_specs" {
#    default = ""
#}

#variable "artifacts" {
#  type = list(object({
#    path = string
#    sha = string
#  }))
#  default = null
#}