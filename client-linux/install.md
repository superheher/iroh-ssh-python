# Target machine: Linux (systemd; python 3.10+)

`irohssh.py serve 22` accepts iroh streams and proxies each into the local
sshd (127.0.0.1:22). The NodeId is stable as long as
`~/.config/iroh-ssh/secret.key` survives.

## Installation

```sh
# 1. a venv with the iroh bindings (same version as the relay)
python3 -m venv ~/.local/share/iroh-ssh/venv
~/.local/share/iroh-ssh/venv/bin/pip install iroh==1.1.0

# 2. the script (shared by all OSes, lives in the repository root)
cp irohssh.py ~/.local/share/iroh-ssh/

# 3. relay token (the access.shared_token value from the relay config)
mkdir -p ~/.config/iroh-ssh && chmod 700 ~/.config/iroh-ssh
printf %s '<relay-token>' > ~/.config/iroh-ssh/token
chmod 600 ~/.config/iroh-ssh/token
# secret.key is created on first run (32 bytes, 0600) -- do not lose it:
# a new key means a new NodeId and the host dropping out of clients'
# ssh configs.

# 4. the systemd --user unit
cp iroh-ssh.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now iroh-ssh

# 5. so the unit survives without an active session (after reboot, before
#    login)
sudo loginctl enable-linger "$USER"
```

## Verification

```sh
systemctl --user status iroh-ssh
journalctl --user -u iroh-ssh -b | grep 'endpoint id'
```

The printed `endpoint id` is the machine's NodeId: clients put it into their
ProxyCommand. Record it somewhere durable.

## Moving to other hardware keeping the same NodeId

Copy `~/.config/iroh-ssh/secret.key` and `token` before the first
`irohssh.py serve` run on the new machine -- the endpoint id then stays
the same.
