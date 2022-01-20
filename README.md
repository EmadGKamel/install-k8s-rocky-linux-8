# Install Kubernetes on Rocky Linux 8, CentOS 8 and compatibles using kubeadm & CRI-O
## Intro
This `bash` script is used to install Kubernetes on Rocky Linux 8 using **kubeadm** & **CRI-O** as a container runtime.

The `install.sh` will configure each node and install main components which are: 
> cri-o, kubelet, kubeadm, kubectl

## Setup cluster nodes
To getting started with installation download this repo and type the following commands:

    chmode +x install.sh
    bash install.sh
After installation each node will reboot and then you can ignite the master node using **kubeadm** command:
    
    kubeadm init
To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
You should now deploy a Pod network to the cluster, for example to use Calico network plugin use the following commands:

    curl https://docs.projectcalico.org/manifests/calico.yaml -O
    kubectl apply -f calico.yaml

After pulling  and spinning up master components images, the **kubeadm init** command will print the joining command that we will use on *worker nodes* which will be in the following syntax:

    kubeadm join <ip-address>:6443\
    --token=<token> \
    --discovery-token-ca-cert-hash sha256:<ca-hash>
You can join any number of machines by running the prioivecs command on each node as root.

To check if worker nodes joined the cluster type the following command

    kubectl get nodes
    
## Install MetalLB 
To install MetalLB use the following commands

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
And apply the following file, the following configuration gives MetalLB control over IPs from `192.168.1.240` to `192.168.1.250`, and configures Layer 2 mode:
    
    apiVersion: v1
    kind: ConfigMap
    metadata:
      namespace: metallb-system
      name: config
    data:
      config: |
        address-pools:
        - name: default
          protocol: layer2
          addresses:
          - 192.168.1.240-192.168.1.250

## Configured CRI-Owith Docker Access token

