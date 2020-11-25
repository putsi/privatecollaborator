#!/bin/bash

ls /opt/BurpSuitePro/BurpSuitePro >/dev/null 2>&1 ||(echo "Install Burp to /opt/BurpSuitePro and run script again" && kill $$ && exit)

DOMAIN=$1

# Get public IP in case not running on AWS, Azure or Digitalocean.
MYPUBLICIP=$(curl http://checkip.amazonaws.com/ -s)
MYPRIVATEIP=$(curl http://checkip.amazonaws.com/ -s)

# Get IPs if running on AWS.
curl http://169.254.169.254/latest -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
  MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)
fi;

# Get IPs if running on Azure.
curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network?api-version=2017-08-01" -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text" -s)
  MYPUBLICIP=$(curl --header 'Metadata: true' "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text" -s)
fi;

# Get IPs if running on Digitalocean.
curl http://169.254.169.254/metadata/v1/id -s --output /dev/null -f -m1
if [ 0 -eq $? ]; then
  # Use Floating IP if the VM has it enabled.
  FLOATING=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/active -s)
  if [ "$FLOATING" == "true" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/ip_address -s)
    MYPRIVATEIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/address -s)
  fi
  if [ "$FLOATING" == "false" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address -s)
    MYPRIVATEIP=$MYPUBLICIP
  fi
fi;

apt update -y && apt install -y python3 python3-pip certbot && pip3 install dnslib
mkdir -p /usr/local/collaborator/
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
chmod +x /usr/local/collaborator/*

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
rm -rf /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" > /etc/resolv.conf

grep $MYPRIVATEIP /etc/hosts -q || (echo $MYPRIVATEIP `hostname` >> /etc/hosts)

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

rm -rf /usr/local/collaborator/keys
certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "*.$DOMAIN, $DOMAIN"  \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
ln -s $CERT_PATH /usr/local/collaborator/keys
