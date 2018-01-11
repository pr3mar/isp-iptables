#!/bin/bash

# Hands-on sample test
# Steps to get the task up && running:
# 1. start up the base virtual image
# 2. install the following packages:
sudo apt update
sudo apt install openssh-server openssh-client wireshark apache2 curl strongswan ipsec-tools

# 3. turn off the base image, make 2 linked clones with MAC addresses reinitialized
# 4. name one of the clones hq and in the network settings enable
#    - Adapter 1 as NAT network, or alternatively, Bridged network
#    - Adapter 2 as Internal Network with the name 'hq_handson'
# 5. name the second clone br and in the network settings enable
#    - Adapter 1 as NAT network, or alternatively, Bridged network
#    - Adapter 2 as Internal Network with the name 'br_handson'
# On both machines, in the /etc/network/interfaces file append the following lines:
# - on the hq machine:
# auto enp0s8
# iface enp0s8 inet static
#  address 10.1.0.1
#  netmask 255.255.0.0
# - on the br machine:
# auto enp0s8 
# iface enp0s8 inet static
#  address 10.2.0.1
#  netmask 255.255.0.0
# on both machines run the following commands
sudo ifup enp0s8
sudo service network-manager restart
## Setting up the VPN
# edit the /etc/ipsec.conf file on both machines
# on the hq machine it should contain the following content:
# config setup
# conn %default
#         ikelifetime=60m
#         keylife=20m
#         rekeymargin=3m
#         keyingtries=1
#         keyexchange=ikev2
#         authby=secret
# conn ho
#         leftsubnet=10.1.0.0/16
#         leftfirewall=yes
#         leftid=@hq
#         right=10.0.2.12
#         rightsubnet=10.2.0.0/16
#         rightid=@br
#         auto=add
# on the br machine it should contain the following content:
# config setup
# conn %default
#         ikelifetime=60m
#         keylife=20m
#         rekeymargin=3m
#         keyingtries=1
#         keyexchange=ikev2
#         authby=secret
# conn ho
#         leftsubnet=10.2.0.0/16
#         leftfirewall=yes
#         leftid=@br
#         right=10.0.2.11
#         rightsubnet=10.1.0.0/16
#         rightid=@hq
#         auto=add
# edit the /etc/ipsec.secrets on both machine it should contain:
# @hq @br : PSK "this_is_my_psk"
# run on both machines
sudo ipsec restart
# setup the connection on only one machine:
sudo ipsec up ho
# to test the connection run
ping 10.2.0.1 # on the hq machine
ping 10.1.0.1 # on the br machine

## Setting up the SSH
# on the br machine run
ssh-keygen -t ecdsa
ssh-id-copy isp@10.0.2.11

# edit /etc/ssh/sshd_config on hq machine
# set the following rule:
# PasswordAuthentication no
# save changes and restart the server with the following command:
sudo service ssh restart
# test on the br machine with the command
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no 10.0.2.11
# it should deny your access

## Setting up the firewall on the hq machine
# first, copy the hands-on template for the firewall
git clone https://github.com/lem-course/isp-iptables.git && cd isp-iptables
# edit the handson-tables.sh file so it includes the following rules:
# iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ### SSH
# iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
# iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT

# ### ICMP (ping)
# iptables -A OUTPUT -p icmp --icmp-type echo-request -m state --state NEW -j ACCEPT
# iptables -A INPUT -p icmp -m icmp --icmp-type address-mask-request -j DROP
# iptables -A INPUT -p icmp -m icmp --icmp-type timestamp-request -j DROP
# iptables -A INPUT -p icmp -m icmp --icmp-type echo-request -j ACCEPT
# ### VPN
# iptables -A INPUT -p udp -m multiport --dports 500,4500 -m state --state NEW -j ACCEPT
# iptables -A OUTPUT -p udp -m multiport --dports 500,4500 -m state --state NEW -j ACCEPT

# iptables -A OUTPUT -p ah -m state --state NEW -j ACCEPT
# iptables -A INPUT -p ah -m state --state NEW -j ACCEPT

# iptables -A OUTPUT -p esp -m state --state NEW -j ACCEPT
# iptables -A INPUT -p esp -m state --state NEW -j ACCEPT

#run the following command to apply the rules and view the rules
sudo ./handson-tables.sh restart && clear && sudo iptables --list -vn
