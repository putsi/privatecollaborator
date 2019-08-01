#!/bin/bash

java -Xms10m -Xmx200m -XX:GCTimeRatio=19 -jar /usr/local/collaborator/burp*.jar --collaborator-server --collaborator-config=/usr/local/collaborator/collaborator.config | grep --line-buffered -vE ' : Received HTTP[S]? polling request from \[' >> /var/www/collaborator/burp.txt
