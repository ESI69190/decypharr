# Decypharr for Synology DSM 7.x and SRM 1.x

This directory contains a SynoCommunity **spksrc overlay** for building Decypharr as a native Synology package (`.spk`).

## Package model

- `SERVICE_USER = auto` creates a dedicated Synology service account.
- Application binaries live below `SYNOPKG_PKGDEST`.
- Persistent configuration, cache and logs live below `SYNOPKG_PKGVAR`.
- Port 8282 is exposed as the administration link.
- rclone, FUSE 2 and FUSE 3 are packaged through spksrc.
- The main Decypharr process remains unprivileged.
- The current stable package line is based on upstream Decypharr v2.7.

Typical DSM layout:

```text
/var/packages/decypharr/
├── target/
│   ├── bin/decypharr
│   ├── bin/rclone
│   ├── bin/fusermount
│   ├── bin/fusermount3
│   ├── bin/decypharr-fuse-fix
│   ├── etc/fuse.conf
│   └── lib/...
└── var/
    ├── data/
    ├── cache/
    └── logs/
```

## DSM FUSE compatibility

Older Synology DSM systems can use Linux 3.10 kernels. Runtime validation on DSM 7.3.1 / DS1817+ (Avoton) showed that newer go-fuse releases could create the mount and then leave it disconnected with:

```text
Transport endpoint is not connected
```

To avoid changing Decypharr's normal Linux/Docker dependency, the Synology build patches only its private source copy to:

- use `github.com/hanwen/go-fuse/v2 v2.5.1`;
- omit the optional `NotifyPrune` cache-pruning call unavailable in go-fuse 2.5.1 while retaining `NotifyEntry` / `NotifyContent` invalidation;
- use `MaxWrite = 128 KiB`;
- use `MaxBackground = 12`;
- use `MaxReadAhead = 128 KiB`;
- keep `AllowOther = true`.

The upstream source tree and non-Synology builds remain unchanged.

## Runtime permission repair

The package reasserts the package-local FUSE helper permissions during install, upgrade and service start. It also repairs ownership of `config.json`, `auth.json` and `torrents.json` before startup so external automation cannot accidentally leave the service unable to read its own state.

The manual helper remains available as a recovery/diagnostic command:

```bash
/var/packages/decypharr/target/bin/decypharr-fuse-fix
```

It validates `/dev/fuse`, the package-local `fuse.conf`, and the `fusermount` / `fusermount3` modes before restarting Decypharr.

## Shared-folder ACLs

The package cannot hard-code shared-folder ACLs because mount paths are user-specific. The package account must be able to traverse the parent directories and write the configured mount directory.

Example:

```bash
MOUNT_ROOT=/volume1/media/_Decypharr
mkdir -p "${MOUNT_ROOT}/mount"

/usr/syno/bin/synoacltool -add /volume1/media   "user:sc-decypharr:allow:--x----------:---n"

/usr/syno/bin/synoacltool -add "${MOUNT_ROOT}"   "user:sc-decypharr:allow:rwxpdDaARWc--:fd--"

/usr/syno/bin/synoacltool -add "${MOUNT_ROOT}/mount"   "user:sc-decypharr:allow:rwxpdDaARWc--:fd--"
```

Consumers such as Sonarr, Radarr, Bazarr and Plex also need traversal access to the parent directories.

## Supported CI targets

The workflow builds DSM 7.3 packages for x86_64, ARM64 and selected ARM32 Synology platforms, plus SRM 1.3 targets. It first runs an apollolake smoke build, then expands to the full matrix.

ARM32 builds use a Synology-cross-compiled rapidyenc static library. The current `mnightingale/rapidyenc` wrapper references the same upstream rapidyenc commit used by the cross package.

## Local build

```bash
bash synology/prepare-spksrc.sh

SHA="$(git rev-parse HEAD)"
DECYPHARR_GIT_HASH="$SHA" \
DECYPHARR_VERSION="0.0.0-dev" \
make -C .synology-build/spksrc/spk/decypharr \
  arch-avoton-7.3 \
  SPK_PACKAGE_ARCHS=avoton
```

Generated packages are written below `.synology-build/spksrc/packages/`.

## Upstream synchronization

This fork keeps Synology-specific changes isolated under `synology/` wherever possible.

Automation uses two tracks:

- `upstream-main` is a machine-owned mirror of `sirrobot01/decypharr:main`, refreshed every two hours.
- `main` is the stable Synology downstream branch. It advances only when upstream publishes a stable GitHub release and the DSM 7.3 avoton package passes validation.

The stable release synchronizer merges the upstream release tag into a temporary `sync/upstream-vX.Y` branch, updates `synology/UPSTREAM_VERSION`, builds the avoton SPK, and only then merges the generated PR into `main` and publishes the matching Synology release.

If an upstream merge conflicts or the Synology package fails to build, `main` and the latest published SPK remain unchanged.
