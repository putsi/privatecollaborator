#!/bin/bash

ls *.jar >/dev/null 2>&1 ||(echo "No Burp JAR found, place it in this directory!" && exit)

DOMAIN=$1
MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)

apt update -y && apt install -y default-jre python-pip && pip install dnslib
mkdir -p /usr/local/collaborator/
cp *.jar /usr/local/collaborator/burp.jar
cp dnshook.sh /usr/local/collaborator/
cp cleanup.sh /usr/local/collaborator/
cp collaborator.config /usr/local/collaborator/collaborator.config
sed -i "s/INT_IP/$MYPRIVATEIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/EXT_IP/$MYPUBLICIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/BDOMAIN/$DOMAIN/g" /usr/local/collaborator/collaborator.config
cp burpcollaborator.service /etc/systemd/system/
cp startcollab.sh /usr/local/collaborator/
cp renewcert.sh /etc/cron.daily/

cd /usr/local/collaborator/
wget -O certbot-auto https://dl.eff.org/certbot-auto
chmod +x /usr/local/collaborator/*

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
rm -rf /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "options edns0" >> /etc/resolv.conf
echo "search eu-north-1.compute.internal" >> /etc/resolv.conf

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

rm -rf /usr/local/collaborator/keys
./certbot-auto certonly --manual-auth-hook ./dnshook.sh --manual-cleanup-hook ./cleanup.sh \
    -d $DOMAIN -d *.$DOMAIN  \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
mkdir -p /usr/local/collaborator/keys/
cp $CERT_PATH/privkey.pem /usr/local/collaborator/keys/
cp $CERT_PATH/fullchain.pem /usr/local/collaborator/keys/
cp $CERT_PATH/cert.pem /usr/local/collaborator/keys/
