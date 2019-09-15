#!/bin/bash

# Yeah, my bash scripting skills suck.

# Define domain name
DOMAIN="BDOMAIN"

# Use public IP in case not running on AWS or Digitalocean.
MYPRIVATEIP=$(curl http://checkip.amazonaws.com/ -s)

# Get private IP if running on AWS.
curl http://169.254.169.254/latest -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
fi;

# Get private IP if running on Digitalocean.
curl http://169.254.169.254/metadata/v1/id -s --output /dev/null -f -m1
if [ 0 -eq $? ]; then
  # Use Floating IP if the VM has it enabled.
  FLOATING=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/active -s)
  if [ "$FLOATING" == "true" ]; then
    MYPRIVATEIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/address -s)
  fi
  if [ "$FLOATING" == "false" ]; then
    MYPRIVATEIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address -s)
  fi
fi;

# Only stop&start burp collaborator if it's already running.
systemctl is-active --quiet burpcollaborator
[ $?  -eq "0" ] && \
/usr/local/collaborator/certbot-auto renew --manual-auth-hook "./dnshook.sh $MYPRIVATEIP"  --manual-cleanup-hook ./cleanup.sh \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --pre-hook "service burpcollaborator stop" --post-hook "service burpcollaborator start" \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01 \
||/usr/local/collaborator/certbot-auto renew --manual-auth-hook "./dnshook.sh $MYPRIVATEIP" --manual-cleanup-hook ./cleanup.sh \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

# Copy certifcates to collaborator directory
CERT_PATH=/etc/letsencrypt/live/$DOMAIN
cp $CERT_PATH/privkey.pem /usr/local/collaborator/keys/
cp $CERT_PATH/fullchain.pem /usr/local/collaborator/keys/
cp $CERT_PATH/cert.pem /usr/local/collaborator/keys/
