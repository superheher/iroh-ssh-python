#!/bin/sh
# /etc/letsencrypt/renewal-hooks/deploy/iroh-relay.sh
# Copies the fresh relay certificate to where iroh-relay reads it.
# No restart needed: cert_mode="Reloading" re-reads the files every 24h.
# Replace <relay-domain> with the domain from certbot certonly -d <relay-domain>.
set -e
[ "${RENEWED_LINEAGE:-}" = "/etc/letsencrypt/live/<relay-domain>" ] || exit 0
install -m 0640 -o root -g iroh "$RENEWED_LINEAGE/fullchain.pem" /etc/iroh-relay/certs/fullchain.pem
install -m 0640 -o root -g iroh "$RENEWED_LINEAGE/privkey.pem"   /etc/iroh-relay/certs/privkey.pem
