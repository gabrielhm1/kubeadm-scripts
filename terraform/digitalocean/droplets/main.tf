locals {
  worker_nodes = [{
    name = "worker-node-01",
    size = "s-2vcpu-2gb"
    },
    {
      name = "worker-node-02",
      size = "s-2vcpu-2gb"
    },
    {
      name = "worker-node-03",
      size = "s-2vcpu-2gb"
  }, ]
}

data "digitalocean_ssh_key" "terraform" {
  name = "mac"
}


resource "digitalocean_vpc" "k8s" {
  name     = "k8s-vpc"
  region   = "nyc3"
  ip_range = "10.10.0.0/16"
}

resource "digitalocean_droplet" "master_node" {
  image    = "ubuntu-20-04-x64"
  name     = "master-node-01"
  region   = "nyc3"
  size     = "s-2vcpu-4gb"
  vpc_uuid = digitalocean_vpc.k8s.id
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]
  monitoring = true

  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "10m"
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
  vpc_uuid = digitalocean_vpc.k8s.id
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]

  monitoring = true
  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    scripts = [
      "../../../scripts/common.sh"
    ]
  }
}

resource "null_resource" "join_worker_nodes" {
  depends_on = [digitalocean_droplet.worker_nodes, digitalocean_droplet.worker_nodes]
  for_each   = digitalocean_droplet.worker_nodes
  triggers = {
    value = length(digitalocean_droplet.worker_nodes)
  }

  provisioner "local-exec" {
    command = <<EOT
      bash ../../../scripts/join_nodes.sh ${digitalocean_droplet.master_node.ipv4_address} ${each.value.ipv4_address} ${var.pvt_key}
    EOT
  }
}
