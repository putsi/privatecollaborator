#!/bin/bash

python3 /usr/local/lib/python$(python3 -V | cut -d' ' -f 2 | cut -d. -f 1,2)/dist-packages/dnslib/fixedresolver.py -r "_acme-challenge.$CERTBOT_DOMAIN. 10 IN TXT \"$CERTBOT_VALIDATION\"" -a $1 &>/dev/null &disown
sleep 5
