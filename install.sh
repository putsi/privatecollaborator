#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 yourdomain.com email@address.com [burp-installer-script.sh]"
  exit 1
fi

DOMAIN=$1
EMAIL=$2
BURP_INSTALLATOR="$3"

if [ ! -f /usr/local/BurpSuitePro/BurpSuitePro ]; then
  if [ -z "$BURP_INSTALLATOR" ]; then
    echo "Install Burp to /usr/local/BurpSuitePro and run script again or provide a path to burp installer script"
    echo "Usage: $0 $DOMAIN email@address.com [burp-installation-path.sh]"
    exit
  elif [ ! -f "$BURP_INSTALLATOR" ]; then
    echo "Burp installer script ($BURP_INSTALLATOR) does not exist"
    exit
  fi
  bash "$BURP_INSTALLATOR" -q
  if [ ! -f /usr/local/BurpSuitePro/BurpSuitePro ]; then
    echo "Burp Suite Pro was not installed correctly. Please install it manually to /usr/local/BurpSuitePro and run the installer script again"
    exit
  fi
fi

# Make sure that permissions are ok for all scripts.
chmod +x *.sh


SRC_PATH="`dirname \"$0\"`"

# Get public IP in case not running on AWS, Azure or Digitalocean.
MYPUBLICIP=$(curl http://checkip.amazonaws.com/ -s)
MYPRIVATEIP=$(hostname -I | cut -d' ' -f 1) # It assumes that first network interface is the Internet one

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

# Use snap version of Certbot because APT-version is too old.
snap install --classic certbot
snap refresh certbot
ln -s /snap/bin/certbot /usr/bin/certbot

apt update -y && apt install -y python3 python3-pip && pip3 install dnslib

mkdir -p /usr/local/collaborator/
cp "$SRC_PATH/dnshook.sh" /usr/local/collaborator/
cp "$SRC_PATH/cleanup.sh" /usr/local/collaborator/
cp "$SRC_PATH/collaborator.config" /usr/local/collaborator/collaborator.config
sed -i "s/INT_IP/$MYPRIVATEIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/EXT_IP/$MYPUBLICIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/BDOMAIN/$DOMAIN/g" /usr/local/collaborator/collaborator.config
cp "$SRC_PATH/burpcollaborator.service" /etc/systemd/system/
cp "$SRC_PATH/startcollab.sh" /usr/local/collaborator/
cp "$SRC_PATH/renewcert.sh" /etc/cron.daily/renewcert

cd /usr/local/collaborator/
chmod +x /usr/local/collaborator/*

grep $MYPRIVATEIP /etc/hosts -q || (echo $MYPRIVATEIP `hostname` >> /etc/hosts)

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

# Wildcard certificate is requested in two steps as it is less error-prone.
# The first step requests the actual wildcard with *.domain.com (all subdomains) certificate.
# The second step expands the certificate with domain.com (without any subdomain).
# This used to be possible in single-step, however currently it can lead to invalid TXT-record error,
# as certbot starts the dnshooks concurrently and not consecutively.
certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" -m $EMAIL --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "*.$DOMAIN" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" -m $EMAIL --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "$DOMAIN, *.$DOMAIN" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01 \
    --expand

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
ln -s $CERT_PATH /usr/local/collaborator/keys
