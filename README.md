# terraform-hetzner-k8s

use in terraform as:

# Create Token
on Hetzner create a token in your Project (API TOKEN r/w)
create a file *terraform.tfvars* like:
```
hcloud_token = "xxxxxx..........xxxxxxxx"
master_nodes=1
worker_nodes=1
```

# Use the module

```
module "hetzner-k8s" {
	source="git::https://github.com/gmarco/terraform-hetzner-k8s.git"
	worker_nodes=1
	master_type = "cx21"
	master_nodes=1
	hcloud_token= var.hcloud_token
}
```

after that do any bootstrap on the cluster 

the module will return the 
masterip: module.$(modulename).master_ip
sshkeyfilename: module.$(modulename).ssh_private_key_filename
all worker und master ips are readable with:

module.hetzner.master_ips , module.hetzner.worker_ips

