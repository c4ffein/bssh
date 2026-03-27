# bssh

Persistent SSH sessions using `screen`. Sessions survive connection drops and can be resumed.

## Install

```sh
# Copy to somewhere in your PATH
cp bssh /usr/local/bin/
```

**Requirements:** `ssh` locally, `screen` on the remote host.

## Usage

```sh
# Connect (creates a new screen session on the remote)
bssh user@hostname

# If a session already exists, bssh offers to reattach
bssh user@hostname

# Use a specific session name
bssh -n myproject user@hostname

# List tracked sessions
bssh -l

# Clean up stale sessions (checks remotes)
bssh -c
```

## How it works

`bssh` wraps SSH + screen so that every connection lands in a persistent `screen` session on the remote host. If your connection drops, the session keeps running — just run `bssh` again to reattach.

- **Session tracking** is stored locally in `~/.bssh_sessions` (a flat file of `host:session_name` pairs). This is just a cache — the real state lives in `screen` on the remote. Every connection validates against the remote and prunes stale entries.
- **Keepalives** are aggressive by default (`ServerAliveInterval=3`, `ServerAliveCountMax=2`) so dead connections are detected in ~6 seconds.
- **File locking** uses atomic `mkdir`-based locks with stale PID detection, so concurrent bssh invocations won't corrupt the sessions file.
- **Screen prefix key** is rebound to `Ctrl-T` (instead of the default `Ctrl-A`) to avoid conflicts with shell shortcuts. Change the `SCREEN_ESCAPE` variable in the script to customize.

## Key bindings (inside a session)

| Key | Action |
|---|---|
| `Ctrl-T d` | Detach (session stays alive, SSH disconnects) |
| `Ctrl-T c` | Create a new screen window |
| `Ctrl-T n` / `Ctrl-T p` | Next / previous window |
| `Ctrl-T ?` | Help |

**Note:** `Ctrl-D` exits the shell and destroys the session — use `Ctrl-T d` to detach safely.

## Tests

Tests run in Docker (two containers: SSH server + client):

```sh
cd test/docker
bash run_tests.sh --build    # build and run all tests
bash run_tests.sh --shell    # interactive shell in the client container
bash run_tests.sh --cleanup  # tear down containers
```

## License

MIT
