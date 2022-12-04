export DEBIAN_FRONTEND=noninteractive
mkdir /etc/docker/
echo '{"exec-opts":
   ["native.cgroupdriver=systemd"]
}' > /etc/docker/daemon.json
apt update 
apt upgrade -y --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 
apt install docker.io -y
systemctl enable docker.service
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -e "s#SystemdCgroup = false#SystemdCgroup = true#"  -i /etc/containerd/config.toml
systemctl restart containerd
apt-add-repository -y "deb http://apt.kubernetes.io/ kubernetes-xenial main"
apt install kubeadm -y
echo $MASTER_IP > /tmp/master_ip
#sudo kubeadm init --apiserver-advertise-address 10.0.0.2 \
#  --service-cidr 10.96.0.0/16   --pod-network-cidr 10.244.0.0/16 \
#  --ignore-preflight-errors=NumCPU
#mkdir -p $HOME/.kube
#sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#https://github.com/solidnerd/terraform-k8s-hcloud/blob/master/scripts/bootstrap.sh
