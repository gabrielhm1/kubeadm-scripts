locals {
  worker_nodes = [{
    name = "worker-node-1",
    size = "s-2vcpu-2gb"
    },
    {
      name = "worker-node-2",
      size = "s-2vcpu-2gb"
  }]
}

data "digitalocean_ssh_key" "terraform" {
  name = "mac"
}

data "digitalocean_vpc" "this" {
  name = "nyc3-vpc-01"
}

# resource "digitalocean_droplet" "worker1" {
#   image  = "ubuntu-20-04-x64"
#   name   = "worker-node-1"
#   region = "nyc3"
#   size   = "s-2vcpu-2gb"
#   vpc_uuid = data.digitalocean_vpc.this.id
#   ssh_keys = [
#     data.digitalocean_ssh_key.terraform.id
#   ]


# #   connection {
# #     host = self.ipv4_address
# #     user = "root"
# #     type = "ssh"
# #     private_key = file(var.pvt_key)
# #     timeout = "2m"
# #   }

# #   provisioner "remote-exec" {
# #     inline = [
# #       "export PATH=$PATH:/usr/bin",
# #       # install nginx
# #       "sudo apt update",
# #       "mkdir k8s",
# #       "cd k8s",
# #       "git clone https://github.com/techiescamp/kubeadm-scripts",
# #       "cd kubeadm-scripts/scripts",
# #       "./common.sh"
# #     ]
# #   }
# }

# resource "digitalocean_droplet" "worker2" {
#   image  = "ubuntu-20-04-x64"
#   name   = "worker-node-2"
#   region = "nyc3"
#   size   = "s-2vcpu-2gb"
#   vpc_uuid = data.digitalocean_vpc.this.id
#   ssh_keys = [
#     data.digitalocean_ssh_key.terraform.id
#   ]
# }

resource "digitalocean_droplet" "master_node" {
  image    = "ubuntu-20-04-x64"
  name     = "master-node-1"
  region   = "nyc3"
  size     = "s-2vcpu-2gb"
  vpc_uuid = data.digitalocean_vpc.this.id
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]

  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    scripts = [
      "../../../scripts/common.sh",
      "../../../scripts/master.sh",
    ]
  }
}

resource "digitalocean_droplet" "worker_nodes" {
  depends_on = [ digitalocean_droplet.master_node ]
  for_each = { for index, node in local.worker_nodes :
  node.name => node }
  image    = "ubuntu-20-04-x64"
  name     = each.value.name
  region   = "nyc3"
  size     = each.value.size
  vpc_uuid = data.digitalocean_vpc.this.id
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]
  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    scripts = [
      "../../../scripts/common.sh"
    ]
  }
}

resource "null_resource" "join_worker_nodes" {
  depends_on = [ digitalocean_droplet.worker_nodes,digitalocean_droplet.worker_nodes ]
  for_each = digitalocean_droplet.worker_nodes
  triggers = {
    value = length(digitalocean_droplet.worker_nodes)
  }

  provisioner "local-exec" {
    command = <<EOT
      bash ../../../scripts/join_nodes.sh ${digitalocean_droplet.master_node.ipv4_address} ${each.value.ipv4_address} ${var.pvt_key}
    EOT
  }
}