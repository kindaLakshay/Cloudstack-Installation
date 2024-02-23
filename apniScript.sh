#!/bin/bash
# apt update && apt upgrade -y

GATEWAY=$(ip r | awk '/default/ {print $3}')
IP=$(ip r | awk '/src/ {print $9}')
ADAPTER=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')


HOSTS_CONTENT="127.0.0.1\tlocalhost\n$IP\lux.lux-uBu.xyz\tlux"
# EXAMPLE
# 127.0.0.1     localhost
# 192.168.122.26    devil.dewansnehra.xyz    devil
apt install bridge-utils


# Check if the bridge already exists
if ! brctl show | grep -q 'br0'; then
    brctl addbr br0
fi

# Check if the interface is already added to the bridge
if ! brctl show br0 | grep -q "$ADAPTER"; then
    brctl addif br0 $ADAPTER
fi

NETPLAN_CONTENT="network:
    version: 2
    renderer: networkd
    ethernets:
        $ADAPTER:
            dhcp4: no
            dhcp6: no
    bridges:
        br0:
            interfaces: [$ADAPTER]
            dhcp4: no
            dhcp6: no
            addresses: [$IP/24]
            gateway4: $GATEWAY
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]"

# network:
# version: 2
# renderer: networkd
# ethernets:
#     enp1s0:
#         dhcp4: no
#         dhcp6: no
# bridges:
#     br0:
#         interfaces: [enp1s0]
#         dhcp4: no
#         dhcp6: no
#         addresses: [192.168.122.26/24]
#         gateway4: 192.168.122.1
#         nameservers:
#             addresses: [8.8.8.8, 8.8.4.4]

CURRENT_GATEWAY=$(grep -oP '(?<=gateway4: )[^ ]*' /etc/netplan/01-network-manager-all.yaml)

if ! grep -Fxq "$HOSTS_CONTENT" /etc/hosts
then
    echo -e "$HOSTS_CONTENT" | sudo tee /etc/hosts
fi

if [ "$CURRENT_GATEWAY" != "$GATEWAY" ]
then
    cp /etc/netplan/01-network-manager-all.yaml /etc/netplan/01-network-manager-all.yaml.bak
    echo "$NETPLAN_CONTENT" | sudo tee /etc/netplan/01-network-manager-all.yaml
fi

systemctl restart NetworkManager
hostnamectl set-hostname lux.lux-uBu.xyz

apt-get install -y openntpd openssh-server sudo vim htop tar intel-microcode bridge-utils mysql-server

UBUNTU_VERSION=$(lsb_release -rs)

if [[ "$UBUNTU_VERSION" == "20."* ]]
then
    echo deb [arch=amd64] http://download.cloudstack.org/ubuntu focal 4.18  > /etc/apt/sources.list.d/cloudstack.list
elif [[ "$UBUNTU_VERSION" == "22."* ]]
then
    echo deb [arch=amd64] http://download.cloudstack.org/ubuntu jammy 4.18  > /etc/apt/sources.list.d/cloudstack.list
else
    echo "Unsupported Ubuntu version. This script supports Ubuntu 20.xx and 22.xx only."
    exit 1
fi


wget -O - http://download.cloudstack.org/release.asc|gpg --dearmor > cloudstack-archive-keyring.gpg


mv cloudstack-archive-keyring.gpg /etc/apt/trusted.gpg.d/


apt update && apt upgrade -y
apt-get install -y cloudstack-management cloudstack-usage



echo -e "\nserver_id = 1\nsql-mode=\"STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION\"\ninnodb_rollback_on_timeout=1\ninnodb_lock_wait_timeout=600\nmax_connections=1000\nlog-bin=mysql-bin\nbinlog-format = 'ROW'" | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf


echo -e "[mysqld]" | sudo tee /etc/mysql/mysql.conf.d/cloudstack.cnf


systemctl restart mysql

echo "
###################################################################################
# In the next command if it will ask for password just press enter and do nothing #
###################################################################################
"

mysql -u root -p -e "
SELECT user,authentication_string,plugin,host FROM mysql.user;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'dewansnehra';
use mysql;
UPDATE user SET plugin='mysql_native_password' WHERE User='root';
flush privileges;   
"
apt-get install -y cloudstack-management cloudstack-usage
cloudstack-setup-databases lux:lux@localhost --deploy-as=root:lux-uBu




ufw allow mysql
mkdir -p /export/primary
mkdir -p /export/secondary
echo "/export *(rw,async,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
apt install nfs-kernel-server
service nfs-kernel-server restart
mkdir -p /mnt/primary
mkdir -p /mnt/secondary
mount -t nfs localhost:/export/primary /mnt/primary
mount -t nfs localhost:/export/secondary /mnt/secondary

echo "
###################################################################################
####           Installation done. You can go to http://localhost:8080          ####
####           to access the pannel.                                           ####
####           Username : admin                                                ####
####           Password : password                                             ####
###################################################################################
"
