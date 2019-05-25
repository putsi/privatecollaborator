#!/bin/bash

# Only stop&start burp collaborator if it's already running. Yeah, my bash scripting skills suck.
systemctl is-active --quiet burpcollaborator
[ $?  -eq "0" ] && \
/usr/local/collaborator/certbot-auto renew --manual-auth-hook ./dnshook.sh --manual-cleanup-hook ./cleanup.sh \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --pre-hook "service burpcollaborator stop" --post-hook "service burpcollaborator start" \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01 \
||/usr/local/collaborator/certbot-auto renew --manual-auth-hook ./dnshook.sh --manual-cleanup-hook ./cleanup.sh \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

