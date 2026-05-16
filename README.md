# koel/franken

Standalone-binary distribution of [Koel](https://github.com/koel/koel),
powered by [FrankenPHP](https://frankenphp.dev) — a single download that bundles
the Caddy webserver, the PHP runtime, and Koel's compiled application code.

No Composer, no Node, no system PHP required on the host.

## Usage

Download the bundle for your platform from the
[Releases](https://github.com/koel/franken/releases) page, extract it, and run:

```bash
tar -xzf koel-franken-v9.2.1-linux-x86_64.tar.gz
cd koel-franken-v9.2.1-linux-x86_64
./koel php-server --listen :8000
```

That's the whole setup. On first run, `./koel` provisions `$HOME/.koel/` with
the conventional layout, generates an `APP_KEY`, and runs migrations against
a fresh SQLite database. Then Caddy serves Koel on the chosen port.

For Artisan commands, prefix with `php-cli`:

```bash
./koel php-cli artisan koel:sync
./koel php-cli artisan tinker
```

## What lives where

Everything writable lives under `$HOME/.koel/`:

| Path | What |
|---|---|
| `$HOME/.koel/.env` | Environment file (Koel's config) |
| `$HOME/.koel/db.sqlite` | SQLite database |
| `$HOME/.koel/storage/` | Laravel storage path (logs, sessions, cache, uploaded images) |
| `$HOME/.koel/storage/app/artifacts/` | Transcodes, downloaded podcast episodes, temp downloads |
| `$HOME/.koel/php.d/koel.ini` | PHP-INI overrides (display_errors=Off, error_reporting masking, 512M uploads) |

The bundle itself (binary + Koel app tree) is conceptually immutable — anything
the user might want to back up or migrate is in `$HOME/.koel/`.

## Local development

To produce a bundle for the current host:

```bash
./build.sh
```

To produce a bundle for a specific Koel/FrankenPHP/platform combination:

```bash
KOEL_VERSION=v9.2.1 \
FRANKENPHP_VERSION=v1.12.2 \
PLATFORM=linux-aarch64 \
  ./build.sh
```

The result lands in `build/koel-franken-<koel-version>-<platform>/`.

Supported platforms: `mac-arm64`, `mac-x86_64`, `linux-x86_64`, `linux-aarch64`.

## How releases are cut

Tag-pushing to this repo triggers `.github/workflows/release.yml`, which builds
all four platform bundles in a matrix on Linux runners (no compilation involved —
each bundle is just `bash launcher + frankenphp binary + extracted koel
tarball`) and uploads them as draft assets on the corresponding GitHub release.

The koel/franken tag should match the Koel version it bundles
(e.g. tag `v9.2.1` on this repo bundles `koel v9.2.1`).
The bundled FrankenPHP version is pinned in the workflow's `FRANKENPHP_VERSION`
env var and bumped via PR.
