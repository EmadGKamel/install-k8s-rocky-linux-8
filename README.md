# Install Kubernetes on Rocky Linux 8, CentOS 8, and compatibles using kubeadm & CRI-O
<center> ** switch to root user before start ** </center>

    sudo su -
## Intro
This `bash` script is used to install Kubernetes on Rocky Linux 8 using **kubeadm** & **CRI-O** as a container runtime.

The file `install.sh` will configure each node and install the main components which are: 
> cri-o, kubelet, kubeadm, kubectl

## Setup cluster nodes
To get started with installation download this repo and type the following commands:

    chmode +x install.sh
    bash install.sh
After installation, each node will reboot and then you can ignite the master node using **kubeadm** command:
    
    kubeadm init
To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
You should now deploy a network plugin Pod to the cluster, for example, to use Calico network plugin use the following commands:

    curl https://docs.projectcalico.org/manifests/calico.yaml -O
    kubectl apply -f calico.yaml

After pulling  and spinning up master components images, the **kubeadm init** command will print the joining command that we will use on *worker nodes* which will be in the following syntax:

    kubeadm join <ip-address>:6443\
    --token=<token> \
    --discovery-token-ca-cert-hash sha256:<ca-hash>
You can join any number of machines by running the previous command on each node as root.

To check if worker nodes joined the cluster type the following command

    kubectl get nodes
    
## Install MetalLB 
To install MetalLB use the following commands:

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
Then use `kubectl` to apply the following configuration, it will gives MetalLB control over IPs from `192.168.1.240` to `192.168.1.250`, and configures Layer 2 mode:
    
    cat <<EOF | kubectl apply -f -
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
    EOF

## Configure CRI-O with Docker Access token
To bypass Docker pull images policy, configure nodes to authenticate to a private registry:

    cat <<EOF | tee -a /etc/crio/crio.conf
    [crio.image]
    global_auth_file="/etc/crio/config.json"
    EOF
Then, in the following command, change the `USERNAME` & `PASSWORD` and apply it.

    cat <<EOF | tee -a /etc/crio/config.json
    {
        "auths": {
            "https://index.docker.io/v1/": {
                "auth": "$(echo -n "<USERNAME>:<PASSWORD>" | base64 -w0)"
            }
        }
    }
    EOF
Then `reboot` your system

    shutdown -r now
