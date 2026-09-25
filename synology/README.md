# Decypharr for Synology DSM 7.x and SRM 1.x

This directory contains a SynoCommunity **spksrc overlay** for building Decypharr as a native Synology package (`.spk`).

The package layout intentionally follows the patterns used by the SynoCommunity packages for Bazarr, Sonarr and Radarr:

- `SERVICE_USER = auto` creates a dedicated Synology service account.
- Application binaries are installed below `SYNOPKG_PKGDEST`.
- Persistent configuration, cache and logs live below `SYNOPKG_PKGVAR`.
- DSM/SRM starts and stops Decypharr through `service-setup.sh`.
- Port 8282 is exposed as the DSM/SRM administration link.
- rclone and libfuse are packaged through existing spksrc cross packages.

## Runtime layout

Typical DSM 7 installation:

```text
/var/packages/decypharr/
├── target/
│   ├── bin/decypharr
│   ├── bin/rclone
│   └── lib/...
└── var/
    ├── data/
    ├── cache/
    └── logs/
```

Decypharr is started as:

```text
decypharr --config /var/packages/decypharr/var/data
```

The package account is managed by Synology (normally `sc-decypharr`). Give that account access to any shared folders Decypharr, Sonarr or Radarr must read.

## Build matrix

The GitHub workflow builds the architecture/toolchain combinations currently exposed by SynoCommunity spksrc for DSM 7.x and SRM 1.x.

| Platform | Toolchain | Architectures |
|---|---|---|
| DSM | 7.0 | x64, aarch64, armv7, evansport, comcerto2k |
| DSM | 7.1 | x64, aarch64, armv7, evansport, comcerto2k |
| DSM | 7.2 | x64, aarch64, armv7 |
| DSM | 7.3 | x64, aarch64, armv7 |
| SRM | 1.2 | armv7 |
| SRM | 1.3 | aarch64, armv7 |

Some older 32-bit targets may eventually need to be declared unsupported if Decypharr's Go/CGO dependencies cannot compile on them. They remain in CI deliberately so support is determined by an actual build rather than assumption.

## Local build

Prepare a pinned spksrc tree and a source archive for the current Decypharr commit:

```bash
bash synology/prepare-spksrc.sh
```

Then build a target, for example:

```bash
SHA="$(git rev-parse HEAD)"

DECYPHARR_GIT_HASH="$SHA" \
DECYPHARR_VERSION="0.0.0-dev" \
make -C .synology-build/spksrc/spk/decypharr arch-x64-7.2
```

The generated package is written below:

```text
.synology-build/spksrc/packages/
```

## FUSE

Decypharr itself is built with CGO and the spksrc `cross/fuse` dependency. This makes the binary and libfuse dependency part of the native package.

Actual filesystem mounting is still subject to DSM/SRM runtime permissions and availability of `/dev/fuse`. The package intentionally does not run the whole Decypharr service as root merely to bypass FUSE restrictions. Runtime FUSE privileges should be solved separately and as narrowly as possible.
