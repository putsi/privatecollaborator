#!/bin/bash

ls *.jar >/dev/null 2>&1 ||(echo "No Burp JAR found, place it in this directory!" && kill $$ && exit)

DOMAIN=$1

# Get public IP in case not running on AWS or Digitalocean.
MYPUBLICIP=$(curl http://checkip.amazonaws.com/ -s)
MYPRIVATEIP=$(curl http://checkip.amazonaws.com/ -s)

# Get IPs if running on AWS.
curl http://169.254.169.254/latest -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
  MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)
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
grep $MYPRIVATEIP /etc/hosts -q || (echo $MYPRIVATEIP `hostname` >> /etc/hosts)

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

rm -rf /usr/local/collaborator/keys
./certbot-auto certonly --manual-auth-hook "./dnshook.sh $MYPRIVATEIP" --manual-cleanup-hook ./cleanup.sh \
    -d $DOMAIN -d *.$DOMAIN  \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
mkdir -p /usr/local/collaborator/keys/
cp $CERT_PATH/privkey.pem /usr/local/collaborator/keys/
cp $CERT_PATH/fullchain.pem /usr/local/collaborator/keys/
cp $CERT_PATH/cert.pem /usr/local/collaborator/keys/

# nginx log view
apt install -y nginx apache2-utils
sed -i "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
rm -v /etc/nginx/sites-enabled/default
cp logview/collaborator.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/collaborator.conf /etc/nginx/sites-enabled/collaborator.conf
sed -i "s/BDOMAIN/$DOMAIN/g" /etc/nginx/sites-enabled/collaborator.conf
cp logview/truncate-log /etc/cron.d/

echo "Create collaborator view login:"
htpasswd -c /etc/nginx/.htpasswd-collaborator collaborator
mkdir /var/www/collaborator
cp logview/index.html /var/www/collaborator/
openssl dhparam -outform pem -out /etc/ssl/dhparam4096.pem 4096
nginx -t && service nginx start
