# iroh-ssh: SSH over a self-hosted iroh relay (Linux / Windows / macOS)

"SSH without an open port": target machines keep an outgoing connection to
your own relay on a VPS, the client reaches them via ssh ProxyCommand. No
sshd port is exposed to the internet -- only the relay, and the relay is
guarded by a token.

```
            +--------------------------+
            | VPS (any Linux)          |
            | iroh-relay 1.1.0         |
            | https://<relay-host>:4443|
            | QUIC :7842/udp, http:4480|
            | shared token, certbot    |
            +-----^-------------^------+
        iroh stream  |         |  iroh stream
     (background     |         | (scheduled task)
      service)       |         |
   +-----------------+--+   +--+----------------------+
   | target (Linux)     |   | target (Windows)       |
   | irohssh.py serve 22|   | irohssh.py serve 22    |
   | systemd --user     |   | Task Scheduler, S4U    |
   | NodeId <target-A>  |   | NodeId <target-B>      |
   +---------^----------+   +----------^-------------+
             |     both proxy into 127.0.0.1:22 (local sshd)
             |                          |
   +---------+--------------------------+-------------+
   | client (macOS / Linux)                          |
   | ProxyCommand irohssh.py stdio <target NodeId>   |
   | (ephemeral endpoint, no secret.key needed)      |
   +--------------------------------------------------+
```

## Deploying on a new machine

The machine's role decides which directory of this repository to deploy:

| role | directory | result |
|---|---|---|
| VPS for the relay | `relay/` | iroh-relay behind TLS + token, systemd |
| target machine, Linux | `client-linux/` | `serve 22` as a systemd --user unit |
| target machine, Windows | `client-windows/` | `serve 22` as a scheduled task |
| client, macOS/Linux | `client-macos/` | `ssh <host>` via ProxyCommand |

Common to all roles: the python script `irohssh.py` from the repository root
(identical on every machine) and the `iroh==1.1.0` package in a venv. The
relay token lives in `~/.config/iroh-ssh/token` (mode 0600). Relay parameters
can be set via environment variables instead of editing the script:
`IROH_RELAY_URL`, `IROH_RELAY_QUIC_PORT`, `IROH_RELAY_TOKEN`.

## Key facts

- ALPN `iroh-ssh-fwd/0`; iroh version 1.1.0 (python bindings and relay).
- A target's NodeId is stable as long as its `~/.config/iroh-ssh/secret.key`
  survives (created on first run). Losing the key = new NodeId = edit the
  ProxyCommand on every client. The client needs no secret.key.
- `irohssh.py` modes: `serve [port]` (server on a target), `forward <id> [port]`
  (local TCP forward), `stdio <id>` (ProxyCommand client).
- `serve` logs diagnostics to stderr, never stdout (in stdio mode stdout
  carries the ssh traffic).

## Secrets

None are committed. Two secrets in the whole scheme:

1. **relay token** -- the value of `access.shared_token` in the relay config;
   the same value sits on every machine in `~/.config/iroh-ssh/token`;
2. **`secret.key`** on every target -- the endpoint's private key, it defines
   the machine's NodeId. Never copy it into the repository.

## Why python and not the rust iroh-ssh

The rust iroh-ssh implementation was tried: its server side with a token in
the URL worked, but the `proxy` client never passes the token to the relay --
the relay answered "denied our authentication" and the tunnel hung silently.
There is no `--relay-token` flag; the token can only be set programmatically
(`RelayMap::with_auth_token`). The python wrapper does exactly that
(`iroh.RelayConfig(auth_token=...)`). The rust variant was removed; it can
come back after an upstream fix.

## Operations

- relay: `systemctl status iroh-relay`, metrics at `127.0.0.1:9090/metrics`;
- Linux target: `journalctl --user -u iroh-ssh -b`;
- Windows target: `%LOCALAPPDATA%\iroh-ssh\serve.log`;
- client debugging: `IROHSSH_DEBUG=1 ssh <host> ...`;
- "hangs with no reply" -- check the client/relay token first: a mismatch
  fails silently (see the rust story above).
