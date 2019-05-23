#!/bin/bash

ls *.jar >/dev/null 2>&1 ||(echo "No Burp JAR found, place it in this directory!" && exit)

DOMAIN=$1
MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)

apt update -y && apt install -y default-jre python-pip && pip install dnslib
mkdir -p /usr/local/collaborator/
cp *.jar /usr/local/collaborator/burp.jar

cp collaborator.config /usr/local/collaborator/collaborator.config
sed -i "s/INT_IP/$MYPRIVATEIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/EXT_IP/$MYPUBLICIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/BDOMAIN/$DOMAIN/g" /usr/local/collaborator/collaborator.config

cd /usr/local/collaborator/
wget https://dl.eff.org/certbot-auto
chmod +x /usr/local/collaborator/*

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "options edns0" >> /etc/resolv.conf
echo "search eu-north-1.compute.internal" >> /etc/resolv.conf

echo ""
echo ""
echo "IMPORTANT: When certbot shows you the DNS TXT-record, don't press enter."
echo "Run the below cmd and give it the value from certbot: "
echo "sudo python /usr/local/lib/python2.7/dist-packages/dnslib/fixedresolver.py -r '_acme-challenge.$DOMAIN. 10 IN TXT \"TXT_VALUE_HERE\"'"
echo "COPY THE ABOVE COMMAND BEFORE CONTINUING!"
echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

rm -rf /usr/local/collaborator/keys
./certbot-auto certonly -d $DOMAIN -d *.$DOMAIN  --server https://acme-v02.api.letsencrypt.org/directory --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

CERT_PATH=/etc/letsencrypt/live/$DOMAIN/
mkdir -p /usr/local/collaborator/keys/
cp $CERT_PATH/privkey.pem /usr/local/collaborator/keys/
cp $CERT_PATH/fullchain.pem /usr/local/collaborator/keys/
cp $CERT_PATH/cert.pem /usr/local/collaborator/keys/
