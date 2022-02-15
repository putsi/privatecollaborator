#!/bin/bash

# Zonefile must be used because certbot tries to start multiple DNS-resolvers for wildcards.
echo "_acme-challenge.$CERTBOT_DOMAIN. 10 IN TXT \"$CERTBOT_VALIDATION\"" >> /tmp/collab.zonefile
pkill -f dnslib.fixedresolver &>/dev/null

# Echo burp service status for CERTBOT_AUTH_OUTPUT so that cleanup can start Burp service if it was started before.
echo "$(systemctl show -p ActiveState --value burpcollaborator)"
service burpcollaborator stop &>/dev/null

python3 -m dnslib.fixedresolver -a $1 --zonefile /tmp/collab.zonefile &>/dev/null &disown

# Sleep to avoid DNS propagation issues.
sleep 10

