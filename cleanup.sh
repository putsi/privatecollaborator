#!/bin/bash

# Kill fixed resolver.
pkill -f dnslib.fixedresolver

# Restart Burp if it was started before renewal process.
if [[ "$CERTBOT_AUTH_OUTPUT" == "active" ]]
then
    service burpcollaborator start
fi

rm -f /tmp/collab.zonefile

