terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "1.4.17"
    }
  }
}

provider "nomad" {
  address = "http://localhost:4646"

}

resource "nomad_namespace" "dev" {
  name = var.namespace

}

resource "nomad_acl_policy" "dev" {
  name        = "dev"
  description = "Submit jobs to the dev environment."

  rules_hcl = <<EOT
namespace "dev" {
  policy = "write"
}
EOT
}

resource "nomad_acl_token" "dev" {
  name = "dev"
  type = "client"
  policies = ["dev"]
}

data "local_file" "template_job_spec" {
  filename = "${path.module}/${var.template_name}"
}

resource "nomad_job" "app" {
  //this needs to be dynamically parsed for look into setproduct
  for_each = toset(var.job_name_prefix)
  jobspec  = templatefile(data.local_file.template_job_spec.filename, {
    job_name = format("%s-%s-%s", each.value, var.job_gen_spec.app_name, var.job_gen_spec.suffix[0])
  })

  hcl2 {
    allow_fs = true
    enabled  = true
    vars     = {
      image = var.image
      group_specs = jsonencode(var.group_specs)
      driver = var.driver
      namespace = var.namespace
    }
  }
  lifecycle {
    ignore_changes = []
  }
}

output "token" {
  value = nomad_acl_token.dev.secret_id
  sensitive = true
}

