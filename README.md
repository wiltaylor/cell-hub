# Cell Hub and Cell Launcher

The server and the desktop library for games packaged in the
[Cell](https://github.com/wiltaylor/cell) format. Cell itself is the
package format: one static file that runs sandboxed on any Linux. This
repository is everything around it.

- **Cell Hub** (`crates/cell-hub`): a catalog people download cells from
  and upload cells to, a host for dedicated game servers that are
  themselves cells, a web admin UI, and a terminal console.
- **Cell Launcher** (`apps/launcher`): a Steam-style desktop library.
  Plays cells, registers them with the desktop or Steam, installs games
  from a hub, joins hosted servers, and pairs with peers.
- **Profiles** (`crates/cell-identity`): keypairs instead of accounts.

## Contents

- [Quick start](#quick-start)
- [Profiles instead of accounts](#profiles-instead-of-accounts)
- [Cell Hub](#cell-hub)
- [Running the hub in Docker](#running-the-hub-in-docker)
- [Cell Launcher](#cell-launcher)
- [Building from source](#building-from-source)
- [Layout](#layout)
- [Releasing](#releasing)
- [License](#license)

## Quick start

```sh
just hub-serve                 # http://localhost:8787; prints the first admin invite code
just launcher                  # the desktop library (needs nothing else to run)
```

Open the launcher, create a profile, point it at the hub on the Hub page,
pair with the invite code from the hub's log, and you are the hub's admin.
Upload a cell from the launcher or with `cell-hub upload game.cell`.

The launcher works without any hub: it plays the `.cell` files in your
games folder. A hub is for downloading and uploading content, hosting
servers and playing with peers.

## Profiles instead of accounts

There are no user accounts. A **profile** is an Ed25519 keypair with a
display name, kept on your machine (`~/.config/cell/profile.json` for the
launcher and the CLI, the browser's local storage for the web UI). The
public key is your identity on every hub and with every peer. Nothing to
sign up for and no password to type: the only passphrase is on the export
file, `name.cellprofile`, which moves a profile to another machine or
browser. The export format is PBKDF2-SHA256 plus AES-256-GCM, so the Rust
side and the browser read the same file. Lose the file and the passphrase
and you pair again; there is no authority to run a reset.

A hub has a profile too and shows its fingerprint. Pairing is a code
exchange:

```sh
cell-hub serve --data ./hub-data        # prints "no admin yet ... invite code: K7F3-9Q2M"
cell-hub profile init --name Wil
cell-hub pair --url http://hub:8787 K7F3-9Q2M     # the first pairing becomes the admin
cell-hub invite --role member            # more codes: admin, operator (named servers), member
cell-hub console                         # signs in with the profile
```

The client signs the code and the hub's public key; the hub stores the
member with the invite's role. Later calls sign a challenge and get a
session token. Roles: `admin` manages the catalog, members and servers;
`operator` controls the servers named on its invite; `member` downloads,
sees servers, and pairs with peers.

**Peers.** Two members pair by exchanging a short code through the hub:
one makes it on the Peers page, the other enters it. Paired peers see each
other's presence (online, in a game) and can send invites to a hosted
server. An invite carries the server's join arguments, so the launcher's
Join button starts the game straight into it.

## Cell Hub

- **Catalog.** Upload cells and their shared runtime layers through the
  web UI, the launcher, or `cell-hub upload file.cell`. Art, grants,
  commands and layer availability come from the cell's manifest.
- **Game servers.** Any cell with a `command "server"` block can be
  hosted. Each instance gets its own state directory, a live console over
  WebSocket with stdin input, a config-file browser and editor rooted at
  the game's home, and tar.gz backups with restore and download. The hub
  runs the cell headless with the host network, so the server listens on
  its usual port.
- **Web UI**, embedded in the binary: library, game pages, servers with
  console, files and backups, members and invites, peers, profile.
- **Terminal console**: `cell-hub console`. Servers on the left, live log
  on the right, a command line at the bottom; F2 start, F3 stop, F4
  restart, F5 backup.

The API is plain JSON under `/api`; `crates/cell-hub-api` holds the types.
A legacy `--token` still works as an admin bearer for scripts.

## Running the hub in Docker

```sh
docker compose -f docker/compose.yaml up -d
docker compose -f docker/compose.yaml logs hub      # the first admin invite code
```

`docker/Dockerfile.hub` builds the web UI and the hub into a 90 MB Debian
image that runs as an unprivileged user with `/data` as its volume;
releases push it to `ghcr.io/wiltaylor/cell-hub`. Game servers inside the
container are cells, so the compose file gives the service `/dev/fuse` and
lifts Docker's seccomp, AppArmor and masked-`/proc` profiles with
`security_opt`; it is not `privileged`. Publish each game server's port
beside `8787`, as the file does for OpenTTD's 3979.

## Cell Launcher

Tauri 2 with a SolidJS front end and a Rust backend. It scans a games
folder (`~/Games/cells` by default) for `.cell` files, shows each one with
its artwork and grants, starts games and their named commands, and runs
the cell's own `install` and `steam-add` commands for desktop and Steam
registration. With a hub configured it installs games with progress,
uploads local cells, lists the hub's servers with Join buttons, pairs with
peers, shows their presence, and pops a toast for invites.

```sh
just launcher            # run (builds first if needed)
just launcher-install    # ~/.local/bin plus an app-menu entry
just launcher-dev        # Vite + Tauri with hot reload
```

Settings live in the app config directory. The window needs webkit2gtk
4.1; the app disables webkit's DMABUF renderer by default because it
shows a blank window on some NVIDIA setups.

## Building from source

- Rust stable.
- Node 20+ and pnpm for the two front ends.
- webkit2gtk 4.1 and GTK 3 development packages for the launcher.
- Docker for the image.

```sh
just hub-build           # web UI + cell-hub
just launcher-build      # front end + Tauri app
just workspace-check     # type checks, fmt, clippy, tests
```

`cell-core`, the file format, comes from the `cell` repository by git tag
(see `Cargo.toml`). Bump the tag there when the format grows.

## Layout

```
crates/cell-hub        the server: API, game-server manager, embedded web UI, console
crates/cell-hub-api    JSON types shared by the hub, the console and the launcher
crates/cell-identity   profiles: keys, invite codes, signed challenges, export; the blocking client
apps/hub-web           the hub's web UI (SolidJS)
apps/launcher          the desktop launcher (SolidJS + Tauri; Rust in src-tauri)
apps/ui                the shared theme and components
docker/                Dockerfile and compose file for the hub
```

## Releasing

CI runs on every push. A push to `main` whose head commit carries a
`release: true` trailer (or `pre-release: true` for an alpha) computes the
version from the conventional-commit subjects since the last `v*` tag,
builds the hub and the launcher, tags, attaches the binaries with a
`SHA256SUMS` file, and pushes the hub image to GHCR.

## License

MIT. See [LICENSE](LICENSE).
