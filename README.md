# koel/franken

Standalone-binary distribution of [Koel](https://github.com/koel/koel),
powered by [FrankenPHP](https://frankenphp.dev) — a single download that
includes the Caddy webserver, the PHP runtime, and Koel itself.

No Composer, no Node, no system PHP needed on the host.

## Usage

Download the archive for your platform from the
[Releases](https://github.com/koel/franken/releases) page, extract it, and run:

```bash
tar -xzf koel-franken-v9.3.3-linux-x86_64.tar.gz
cd koel-franken-v9.3.3-linux-x86_64
./koel php-server --listen :8000
```

On first run, Koel sets up `$HOME/.koel/`, generates an app key, and creates a
fresh SQLite database. Then it starts serving on the chosen port.

For Artisan commands, use the `./artisan` shortcut:

```bash
./artisan koel:sync
./artisan tinker
```

## Upgrading

To upgrade to a newer release:

1. Download the new archive from the [Releases](https://github.com/koel/franken/releases) page.
2. Extract it over the existing directory.
3. Restart the server.

Your data in `$HOME/.koel/` — settings, database, uploaded images, search
indexes — is preserved across upgrades.

## What lives where

Everything writable lives under `$HOME/.koel/`:

| Path | What |
|---|---|
| `$HOME/.koel/.env` | Environment file (Koel's config) |
| `$HOME/.koel/db.sqlite` | SQLite database |
| `$HOME/.koel/storage/` | Laravel storage path (logs, sessions, cache, uploaded images) |
| `$HOME/.koel/storage/app/artifacts/` | Transcodes, downloaded podcast episodes, temp downloads |
| `$HOME/.koel/php.d/koel.ini` | PHP-INI overrides (512M uploads, longer timeouts) |

See the [Standalone Binary guide](https://github.com/koel/koel/blob/master/docs/guide/standalone-binary.md)
for customization, systemd setup, and running behind a reverse proxy.

## Local development

To build for the current host:

```bash
./build.sh
```

To build a specific Koel/FrankenPHP/platform combination:

```bash
KOEL_VERSION=v9.3.3 \
FRANKENPHP_VERSION=v1.12.2 \
PLATFORM=linux-aarch64 \
  ./build.sh
```

The result lands in `build/koel-franken-<koel-version>-<platform>/`.

Supported platforms: `mac-arm64`, `mac-x86_64`, `linux-x86_64`, `linux-aarch64`.

## How releases are cut

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds all
four platforms in parallel and uploads them as draft assets on the GitHub
release.

The koel/franken tag matches the Koel version it ships
(e.g. tag `v9.3.3` ships `koel v9.3.3`).
The FrankenPHP version is pinned in the workflow's `FRANKENPHP_VERSION` env
var and bumped via PR.
