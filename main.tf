terraform {
  required_providers {
    hcloud= {
      #source  = "registry.terraform.io/hashicorp/hcloud"
      source  = "hetznercloud/hcloud"
      #version = "1.32.1"
    }
  }
}

resource tls_private_key ssh_key {
   algorithm = "RSA"
}


resource local_file private_key {
    sensitive_content = tls_private_key.ssh_key.private_key_pem
    filename = "${path.root}/hetzner"
    file_permission = "0600"
}

resource local_file public_key {
    sensitive_content = tls_private_key.ssh_key.public_key_openssh
    filename = "${path.root}/hetzner.pub"
    file_permission = "0600"
}

resource "hcloud_ssh_key" "default" {
  name       = "Terraform Example"
  public_key = tls_private_key.ssh_key.public_key_openssh
}


provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_network" "private" {
  name     = var.cluster_name
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

data "template_file" "master_init" {
  template = file("${path.module}/templates/init.sh")
}


resource "hcloud_server" "master" {
  count = var.master_nodes
  name        = "${var.cluster_name}-master-${count.index}"
  #datacenter  = var.datacenter
  image       = var.image
  server_type = var.master_type
  ssh_keys    = [hcloud_ssh_key.default.id]
  location = var.location
  #user_data   = data.template_file.master_init.rendered
  keep_disk   = true
  network  {
    network_id  = hcloud_network.private.id
    ip = count.index==0 ? "10.0.0.2" : "10.0.0.${count.index+2}"
  }

  connection {
    host        = self.ipv4_address#
    type        = "ssh"
    private_key = file(local_file.private_key.filename)
    }
    provisioner "file" {
    source      = "${path.module}/scripts/bootstrap.sh"
    destination = "/root/bootstrap.sh"
    }

  provisioner "remote-exec" {
    inline = ["MASTER_IP={hcloud_server.master[0].ipv4_address} DOCKER_VERSION1=${var.cluster_name} KUBERNETES_VERSION1=${var.cluster_name} bash /root/bootstrap.sh"]
  }
}

resource "hcloud_server" "worker" {
  count = var.worker_nodes
  name        = "${var.cluster_name}-worker-${count.index}"
  #datacenter  = var.datacenter
  image       = var.image
  server_type = var.node_type
  ssh_keys    = [hcloud_ssh_key.default.id]
  location = var.location
#user_data   = data.template_file.master_init.rendered
  keep_disk   = true

  network  {
    network_id  = hcloud_network.private.id
    ip = count.index==0 ? "10.0.0.22" : "10.0.0.${count.index+22}"
  }

  connection {
    host        = self.ipv4_address
    type        = "ssh"
    private_key = file(local_file.private_key.filename)
  }
  provisioner "file" {
  source      = "${path.module}/scripts/bootstrap.sh"
  destination = "/root/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = ["MASTER_IP={hcloud_server.master[0].ipv4_address} DOCKER_VERSION1=${var.cluster_name} KUBERNETES_VERSION1=${var.cluster_name} bash /root/bootstrap.sh"]
  }


}


resource null_resource "master_init" {
  triggers = {
    cluster_instance_ids = "${join(",", [hcloud_server.master[0].id])}"
  }
  connection {
    host        = hcloud_server.master[0].ipv4_address
    type        = "ssh"
    private_key = file(local_file.private_key.filename)
  }
  provisioner "file" {
    source      = "${path.module}/secrets/kubeadm.config"
    destination = "/tmp/kubeadm.config"
  }

  provisioner "remote-exec" {
    inline = ["sudo kubeadm init --config /tmp/kubeadm.config --ignore-preflight-errors=NumCPU",
      "mkdir -p $HOME/.kube",
      "sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config ",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "kubeadm token create --print-join-command > /tmp/kubeadm_join",
      "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
      ]
  }
  provisioner "local-exec" {
   command = "bash ${path.module}/scripts/copy-token.sh"

   environment = {
     SSH_PRIVATE_KEY = local_file.private_key.filename
     SSH_USERNAME    = "root"
     SSH_HOST        = hcloud_server.master[0].ipv4_address
     TARGET          = "${path.module}/secrets/"
   }
 }

}


locals {

  inputs = {
    all_server_ids = slice(concat(hcloud_server.master[*].id,hcloud_server.worker[*].id),1,length(hcloud_server.master)+length(hcloud_server.worker))
    all_server_ips = slice(concat(hcloud_server.master[*].ipv4_address,hcloud_server.worker[*].ipv4_address),1,length(hcloud_server.master)+length(hcloud_server.worker))
  }
  #nodes=slice(merge(hcloud_server.master[*],hcloud_server.worker[*]),1,length(hcloud_server.master)+length(hcloud_server.worker))
}

resource "null_resource" "join_nodes1"{
  triggers = {
    cluster_instance_ids = "${join(",",concat(hcloud_server.master[*].id,hcloud_server.worker[*].id))}"
  }

  #init only no bootstrapped
  #for_each = {
#    for key,value in hcloud_server.worker:
    ##for key,value in hcloud_server.worker[*]:
    #value.ipv4_address => value #if value.tags["bootstrapped"]!=true ?

#  }


}

#kubectl taint nodes $(kubectl get nodes --selector=node-role.kubernetes.io/master | awk 'FNR==2{print $1}') node-role.kubernetes.io/master-
resource "null_resource" "join_nodes"{
  triggers = {
    cluster_instance_ids = "${join(",",concat(hcloud_server.master[*].id,hcloud_server.worker[*].id))}"
  }
  count=length(local.inputs["all_server_ips"])


  connection {
    host        = local.inputs["all_server_ips"][count.index]
    type        = "ssh"
    private_key = file(local_file.private_key.filename)
  }

  provisioner "file" {
    source      = "${path.module}/secrets/kubeadm_join"
    destination = "/tmp/kubeadm_join"

    connection {
      host        = local.inputs["all_server_ips"][count.index]
      type        = "ssh"
      user        = "root"
      private_key = file(local_file.private_key.filename)
    }
  }

  provisioner "remote-exec" {
    inline = ["[ -f /etc/kubernetes/kubelet.conf ] || bash /tmp/kubeadm_join" ]
  }

  depends_on=[
    null_resource.master_init,
    hcloud_server.master[0],
  ]
}

#resource "hcloud_server_network" "master" {
#  for_each = {for i in concat(hcloud_server.master[*],hcloud_server.worker[*]) : i.name => i.id}
#  server_id = each.value
#  subnet_id = hcloud_network_subnet.subnet.id
#}

output "master_ip_ssh" {
  value="ssh -o StrictHostKeyChecking=no  root@${hcloud_server.master[0].ipv4_address} -i hetzner"
}


output "master_ip" {
  value = hcloud_server.master[0].ipv4_address
}
output "ssh_private_key_filename" {
  value = local_file.private_key.filename
}

output "master_ips" {
  value = hcloud_server.master[*].ipv4_address
}

output "worker_ips" {
  value = hcloud_server.worker[*].ipv4_address
}