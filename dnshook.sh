#!/bin/bash

MYPRIVATEIP=$1
MYPUBLICIP=$(curl -s http://checkip.amazonaws.com/)

# Ensure CERTBOT_DOMAIN and CERTBOT_VALIDATION are set
if [[ -z "$CERTBOT_DOMAIN" || -z "$CERTBOT_VALIDATION" ]]; then
  echo "CERTBOT_DOMAIN and CERTBOT_VALIDATION must be set"
  exit 1
fi

# Create the DNS zone file
cat <<EOF > /tmp/collab.zonefile
\$TTL 10
@ IN SOA ns1.$CERTBOT_DOMAIN. hostmaster.$CERTBOT_DOMAIN. (
    2024062501 ; serial
    3600       ; refresh (1 hour)
    1800       ; retry (30 minutes)
    1209600    ; expire (2 weeks)
    3600       ; minimum (1 hour)
)

@ IN NS ns1.$CERTBOT_DOMAIN.
@ IN A $MYPUBLICIP

_acme-challenge.$CERTBOT_DOMAIN. 10 IN TXT "$CERTBOT_VALIDATION"

$CERTBOT_DOMAIN. 10 IN CAA 0 issue "letsencrypt.org"
EOF

# Kill any existing dnslib.fixedresolver processes
pkill -f dnslib.fixedresolver &>/dev/null

# Echo burp service status for CERTBOT_AUTH_OUTPUT so that cleanup can start Burp service if it was started before.
echo "$(systemctl show -p ActiveState --value burpcollaborator)"
service burpcollaborator stop &>/dev/null

python3 -m dnslib.fixedresolver -a $MYPRIVATEIP --zonefile /tmp/collab.zonefile &>/dev/null &

# Sleep to avoid DNS propagation issues.
sleep 15
