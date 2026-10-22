# Client: macOS or any Linux with ~/.ssh

The client only consumes: no `serve`, no permanent NodeId, no secret.key.
`irohssh.py stdio <endpoint-id>` lives for exactly one ssh session
(ProxyCommand), with a fresh ephemeral endpoint id each time -- which is why
servers see the client under different ids in their logs.

## Installation

```sh
python3 -m venv ~/.local/share/iroh-ssh/venv
~/.local/share/iroh-ssh/venv/bin/pip install iroh==1.1.0
cp irohssh.py ~/.local/share/iroh-ssh/

# relay token (the access.shared_token value from the relay config);
# no secret.key needed
mkdir -p ~/.config/iroh-ssh && chmod 700 ~/.config/iroh-ssh
printf %s '<relay-token>' > ~/.config/iroh-ssh/token
chmod 600 ~/.config/iroh-ssh/token

# hosts in ~/.ssh/config -- see ssh_config-snippet:
# put each target's endpoint id into its ProxyCommand
```

If the relay is not the default one, set `IROH_RELAY_URL` /
`IROH_RELAY_QUIC_PORT` in the environment (or via `SetEnv`/`SendEnv` in the
ssh config, whichever you prefer).

## Verification

```sh
ssh target-a 'hostname'
```

Wrapper debugging: `IROHSSH_DEBUG=1` before ssh makes irohssh.py print
diagnostics to stderr (it does not disturb the traffic, that lives in
stdout).

## Alternative without touching ssh_config: local forward

`irohssh.py forward <endpoint-id> 2222` opens TCP port 127.0.0.1:2222 on the
client; then a plain `ssh -p 2222 user@127.0.0.1`. Handy for tools that do
not support ProxyCommand.
