#!/bin/bash

# This script uses ugly DNS-hack which allows you to redirect all main domain (non-subdomain) HTTP-requests to another IP.
# For example:
# gcwtg9e6xjny3wvglltchxnjjap8dx.collab.fi -> Passed to Burp Collaborator
# www.collab.fi -> Passed to 1.2.3.4
# collab.fi -> Passed to 1.2.3.4

# Replace with the web server IP that will serve HTML for the main domain.
TARGET_IP=1.2.3.4
# Replace with your collaborator domain.
MAIN_DOMAIN=collab.fi

apt install -y python-nfqueue build-essential python-dev libnetfilter-queue-dev
pip install scapy
sed -i "s/TARGET_IP/$TARGET_IP/g" dnsmitm.py
sed -i "s/MAIN_DOMAIN/$MAIN_DOMAIN/g" dnsmitm.py

cp dnsmitm.service /etc/systemd/system/
cp dnsmitm.py /usr/local/collaborator/

iptables -A INPUT -p udp -m udp --dport 53 -j NFQUEUE --queue-num 1
iptables-save > /etc/iptables/rules.v4
apt install -y iptables-persistent

systemctl enable dnsmitm
systemctl start dnsmitm

echo "Installed dnsmitm-service, enabled start on boot and started"
