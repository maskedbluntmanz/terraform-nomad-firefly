variable "image" {}
variable "driver" {}
variable "group_specs" {}
variable "namespace" {}
#variable "task_specs" {}

job "${job_name}" {
  namespace = var.namespace
  datacenters = ["dc1"]
  dynamic "group" {
    for_each = jsondecode(var.group_specs)
    iterator = group
    labels = [group.value.group_label]
    content {
      meta {
        image = var.image
      }

      network {
        port "db" {
          to = 6379
        }
      }

      task "redis" {
        driver = var.driver

        config {
          image = "$${NOMAD_META_image}"

          ports = ["db"]
        }

        resources {
          cpu    = 500
          memory = 256
        }
      }
    }
  }

}
