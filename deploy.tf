// Copyright 2021 Yoshi Yamaguchi
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

variable "project_id" {
    type = string
    description = "Google Cloud Platform project ID"
    default = "yoshifumi-cloud-demo"
}

variable "region" {
    type = string
    description = "Google Compute Engine region"
    default = "asia-northeast2"
}

variable "zone" {
    type = string
    description = "Google Compute Engine zone"
    default = "asia-northeast2-a"
}

variable "gce_ssh_user" {
    type = string
    description = "username for SSH"
    default = "demo"
}

variable "gce_ssh_pub_key_file" {
    type = string
    description = "path to the public key file"
    default = "~/.ssh/gcp_terraform.pub"
}

variable "gcp_service_account_file" {
    type = string
    description = "path to service account credential file"
    default = "~/.credentials/yoshifumi-cloud-demo.json"
}


provider "google" {
    project = var.project_id
    zone = var.zone
    region = var.region
}

locals {
    ansible_inventory = <<-EOT
        ---
        plugin: gcp_compute
        auth_kind: serviceaccount
        service_account_file: "${var.gcp_service_account_file}"
        zones:
        - "${var.zone}"
        projects:
        - "${var.project_id}"
        hostnames:
        - 'name'
        compose:
          ansible_host: networkInterfaces[0].accessConfigs[0].natIP
    EOT
}

resource "local_file" "ansible_inventory_file" {
    filename = "inventory.gcp.yaml"
    content = local.ansible_inventory
}

resource "google_compute_instance" "shakesapp" {
    name = "shakesapp"
    machine_type = "e2-standard-2"
    zone = var.zone
    tags = ["shakesapp-demo"]

    depends_on = [
        local_file.ansible_inventory_file,
    ]
    boot_disk {
        initialize_params {
            image = "debian-cloud/debian-10"
        }
    }

    network_interface {
        network = "default"
        access_config {}
    }

    scheduling {
        automatic_restart = true
    }

    service_account {
        scopes = [
            "https://www.googleapis.com/auth/compute",
            "https://www.googleapis.com/auth/logging.write",
            "https://www.googleapis.com/auth/monitoring",
        ]
    }

    metadata = {
        block-project-ssh-keys = "true"
        ssh-keys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
    }

    provisioner "remote-exec" {
        inline = ["echo hello"]
        connection {
            type = "ssh"
            host = self.network_interface[0].access_config[0].nat_ip
            user = var.gce_ssh_user
            private_key = file("~/.ssh/gcp_terraform")
        }
    }

    provisioner "local-exec" {
        working_dir = "."
        command = "ansible-playbook -i inventory.gcp.yaml deploy.yaml"
    }
}