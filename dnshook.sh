#!/bin/bash

python /usr/local/lib/python2.7/dist-packages/dnslib/fixedresolver.py -r "_acme-challenge.$CERTBOT_DOMAIN. 10 IN TXT \"$CERTBOT_VALIDATION\"" -a $1 &>/dev/null &disown
