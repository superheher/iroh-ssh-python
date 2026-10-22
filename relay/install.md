# Relay (a VPS, any systemd Linux; tested on Ubuntu 22.04, x86_64)

The machine's only role in this scheme is iroh-relay. There is and must be
no iroh ssh server here: clients reach their targets through the relay
directly, the relay only carries traffic. Footprint: ~12 MB RSS.

## Installation

```sh
# 1. system user without a shell or home
useradd --system --home /nonexistent --shell /usr/sbin/nologin iroh

# 2. config and certificate directories
install -d -m 0750 -o root -g iroh /etc/iroh-relay/certs

# 3. the binary -- a static ELF from the n0-computer/iroh GitHub releases
#    (~10 MB file, version 1.1.0; drop it in as is)
install -m 0755 iroh-relay /usr/local/bin/iroh-relay
/usr/local/bin/iroh-relay --version   # iroh-relay 1.1.0

# 4. config: substitute <relay-shared-token> (openssl rand -base64 30)
install -m 0640 -o root -g iroh config.toml /etc/iroh-relay/config.toml

# 5. systemd unit
install -m 0644 iroh-relay.service /etc/systemd/system/iroh-relay.service
systemctl daemon-reload && systemctl enable --now iroh-relay

# 6. the <relay-domain> certificate (ECDSA) via certbot, lineage
#    /etc/letsencrypt/live/<relay-domain>; renewal is automatic.
#    The deploy hook copies it to where the relay reads it
#    (substitute your domain for <relay-domain>):
install -m 0755 certbot-deploy-hook.sh \
        /etc/letsencrypt/renewal-hooks/deploy/iroh-relay.sh

# 7. firewall (if 80/443 are taken by a web server, the relay lives on its
#    own ports)
ufw allow 4443/tcp comment 'iroh-relay'   # relay over TLS (the main one)
ufw allow 4480/tcp comment 'iroh-relay'   # http: captive-portal probe
ufw allow 7842/udp comment 'iroh-relay'   # QUIC address discovery
```

DNS: an A record for `<relay-domain>` pointing at this VPS.

## Verification

```sh
systemctl status iroh-relay
ss -tlnp | grep -E '4443|4480|9090'          # metrics on 127.0.0.1:9090 only
curl -s "https://<relay-domain>:4443/health_check"
```

Metrics: `curl 127.0.0.1:9090/metrics`.

## Why the relay needs a token

The relay is exposed to the internet; `access.shared_token` admits only your
own clients: the token travels as `?token=` (or a Bearer header), and the
python wrapper on the clients passes it programmatically via
`iroh.RelayConfig(auth_token=...)`.
