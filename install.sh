#!/bin/bash

#/* ************************************************************** Intro start *********************************************************** */
#/*
# *
# *     Auother:    Emad Gamal Kamel
# *     Email:      emadg.kamel@gmail.com
# *     Client:     Corfitz Bramsted
# *     Broker:     Upwork
# *     Task:       Create on-prem K8S cluster using Rocky Linux, Cri-o, MetalLb, kubeadm and Calico
# *
#/* ************************************************************** Intro End ************************************************************** */

#!/bin/bash -x

echo "This script is written to work with Rocky Linux 8, CentOS 8 and compatibles"
echo

## Disable firewall starting from Kubernetes v1.19 onwards
sleep 3
echo
echo "Disabling firewalld"
echo 
systemctl disable firewalld; systemctl stop firewalld


## Backup fstab & disable swap 
sleep 3
echo
echo "Disabling swap"
echo 
cp -f /etc/fstab /etc/fstab.bak
sed -i '/swap/d' /etc/fstab
swapoff -a


## Set SELinux in disable mode 
sleep 3
echo
echo "Disabling selinux"
echo 
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux


# sleep 3
# echo
# echo "Adding hostnames to /etc/hosts file"
# echo 
# cat >>/etc/hosts<<EOF
# 172.16.16.100   k8s-master-01.example.com     k8s-master-01
# 172.16.16.101   k8s-worker-01.example.com     k8s-worker-01
# EOF


## Install needed tools during installation 
sleep 3
echo
echo "Install basic tools"
echo 
yum update -y
yum install -y epel-release
yum update -y
yum install -y yum-utils git wget curl vim htop bash-completion nfs-utils bash-completion


## The following section is creating some configuration files that letting ipTables see bridged networks as specified by CRI-O documentation
sleep 3
echo
echo "Update Kernel modules and sysctl settings"
echo 
{
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

cat <<EOF | tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
}


## configuring Kubernetes & CRI-O repositories
sleep 3
echo
echo "Update node repos and install dependencies"
echo 
{
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

#set OS version
OS=CentOS_8
 
#set CRI-O version
VERSION=1.23

curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
}


## Installing CRI-O & K8s components
sleep 3
echo
echo "Install kubeadm, kubelet & kubectl"
echo 
yum repolist -y
yum update -y
yum install -y cri-o cri-tools
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes


## Editing kubeadm config file
sleep 3
echo
echo "Editing kubeadm config file"
echo 
KUBELET_PATH=/usr/lib/systemd/system/kubelet.service.d
cp -f $KUBELET_PATH/10-kubeadm.conf $KUBELET_PATH/10-kubeadm.conf.bak
sed -i '8 a Environment=\"KUBELET_CGROUP_ARGS=--cgroup-driver=systemd\"' $KUBELET_PATH/10-kubeadm.conf
sed -i '/^ExecStart=\// s/$/ \$KUBELET_CGROUP_ARGS/' $KUBELET_PATH/10-kubeadm.conf


## Reloading systemctl daemon
sleep 3
echo
echo "Reloading systemctl, CRI-O & kubelet daemons"
echo 
systemctl daemon-reload
systemctl enable crio --now
systemctl enable kubelet --now

echo 
echo 
echo "All configuration done successfully..."
echo
echo "*** This node will reboot in 10 sec, once rebooting you can issue \"kubeadm init\" command on master node. ***"
echo
echo "Happy Kubernetes"
sleep 10 ; reboot
