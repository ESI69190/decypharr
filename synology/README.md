# Decypharr for Synology DSM 7.x and SRM 1.x

Current stable release line: **2.5**. The Synology FUSE compatibility candidate is **2.5.1**.

This directory contains a SynoCommunity **spksrc overlay** for building Decypharr as a native Synology package (`.spk`).

The package layout follows the same model as the SynoCommunity packages for Bazarr, Sonarr and Radarr:

- `SERVICE_USER = auto` creates a dedicated Synology service account.
- Application binaries live below `SYNOPKG_PKGDEST`.
- Persistent configuration, cache and logs live below `SYNOPKG_PKGVAR`.
- DSM/SRM controls the process through `service-setup.sh`.
- Port 8282 is exposed as the administration link.
- rclone, FUSE 2 and FUSE 3 are packaged through spksrc. FUSE 2 is used by Decypharr/cgofuse and FUSE 3 provides the `fusermount3` helper required by rclone.

## Runtime layout

Typical DSM 7 installation:

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

Decypharr is started as:

```text
decypharr --config /var/packages/decypharr/var/data
```

The package account is managed by Synology, normally as `sc-decypharr`. Give that account access to the shared folders Decypharr, Sonarr or Radarr must read.

## DSM 7 FUSE post-install

DSM 7 rejects third-party SPKs that declare root execution privileges and strips or blocks setuid-root helpers from unsigned packages. Decypharr therefore installs and runs entirely as the unprivileged `sc-decypharr` package account.

After each install or upgrade, an administrator must explicitly enable the two FUSE mount helpers:

```bash
/var/packages/decypharr/target/bin/decypharr-fuse-fix
```

The helper requests `sudo` when required, changes only `fusermount` and `fusermount3` to `root:root 4755`, verifies the package-local `etc/fuse.conf`, and restarts Decypharr. The main Decypharr process remains unprivileged.

Verify with:

```bash
stat -c '%A %a %U:%G %n' \
  /var/packages/decypharr/target/bin/fusermount \
  /var/packages/decypharr/target/bin/fusermount3

sudo -u sc-decypharr \
  cat /var/packages/decypharr/target/etc/fuse.conf
```

For DSM shared folders, the package user must also be able to traverse the shared-folder parent and read/write the Decypharr mount directory. For the validated `VideoFactory` layout:

```bash
mkdir -p /volume1/VideoFactory/_Decypharr/mount

/usr/syno/bin/synoacltool -add \
  /volume1/VideoFactory \
  "user:sc-decypharr:allow:--x----------:---n"

/usr/syno/bin/synoacltool -add \
  /volume1/VideoFactory/_Decypharr \
  "user:sc-decypharr:allow:rwxpdDaARWc--:fd--"

/usr/syno/bin/synoacltool -add \
  /volume1/VideoFactory/_Decypharr/mount \
  "user:sc-decypharr:allow:rwxpdDaARWc--:fd--"

sudo -u sc-decypharr touch \
  /volume1/VideoFactory/_Decypharr/mount/.write-test
rm -f /volume1/VideoFactory/_Decypharr/mount/.write-test
```

Sonarr and Radarr also need to traverse the Synology shared-folder parents before the kernel can reach the FUSE mount. With `allow_other`, the FUSE root itself is readable according to its exposed POSIX modes, so only parent traversal/browsing permissions are required:

```bash
for user in sc-sonarr sc-radarr; do
    /usr/syno/bin/synoacltool -add \
      /volume1/VideoFactory \
      "user:${user}:allow:--x----------:---n"

    /usr/syno/bin/synoacltool -add \
      /volume1/VideoFactory/_Decypharr \
      "user:${user}:allow:r-x----------:---n"
done
```

Validate with:

```bash
for user in sc-sonarr sc-radarr; do
    echo "===== ${user} ====="
    sudo -u "${user}" ls -la \
      /volume1/VideoFactory/_Decypharr/mount
    sudo -u "${user}" cat \
      /volume1/VideoFactory/_Decypharr/mount/version.txt
done
```

The package does not hard-code these ACLs because the shared-folder and mount paths are user-specific.

### DSM Hanwen compatibility mode

The native Synology service enables `DECYPHARR_SYNOLOGY_FUSE_COMPAT=1`. This keeps Hanwen/go-fuse at the upstream 2.8.0 dependency while using a conservative FUSE handshake on DSM:

```text
MaxWrite       = 128 KiB
MaxBackground  = 12
MaxReadAhead   = 128 KiB
AllowOther     = true
```

Generic Linux and Docker deployments keep the normal Decypharr FUSE settings.


## Supported package architectures

The CI intentionally targets the Synology package architectures requested for DSM 7.x and SRM 1.x.

### DSM 7.x

All DSM packages are built against DSM 7.3-compatible spksrc toolchains:

```text
apollolake
avoton
braswell
broadwell
broadwellnk
broadwellnkv2
broadwellntbap
bromolow
denverton
epyc7002
epyc7003
epyc7003ntb
geminilake
geminilakenk
grantley
icelaked
kvmx64
purley
r1000
r1000nk
v1000
v1000nk
alpine
alpine4k
armada38x
monaco
armada37xx
rtd1619b
```

For `epyc7003ntb` and `icelaked`, the workflow uses the DSM 7.3 generic `x64` toolchain and restricts the generated package metadata with `SPK_PACKAGE_ARCHS`. The other listed targets use their dedicated DSM 7.3 toolchain.

### SRM 1.x

SRM packages are built with the SRM 1.3 toolchains:

```text
dakota
ipq806x
cypress
```

## CI behavior

The workflow first performs a complete DSM 7.3 `apollolake` smoke build. The remaining architecture matrix starts only after that package succeeds. This prevents a common packaging error from wasting the entire matrix.

Each generated SPK is architecture-specific through `SPK_PACKAGE_ARCHS`, even when a generic family toolchain is used for compilation.

## Local build

Prepare a pinned spksrc tree and a source archive for the current Decypharr commit:

```bash
bash synology/prepare-spksrc.sh
```

Then build a target, for example:

```bash
SHA="$(git rev-parse HEAD)"

DECYPHARR_GIT_HASH="$SHA" \
DECYPHARR_VERSION="2.5" \
make -C .synology-build/spksrc/spk/decypharr \
  arch-apollolake-7.3 \
  SPK_PACKAGE_ARCHS=apollolake
```

The generated package is written below:

```text
.synology-build/spksrc/packages/
```

## CGO and FUSE

Decypharr uses `github.com/winfsp/cgofuse`. On Linux it expects the FUSE 2 headers. The spksrc `cross/fuse` dependency stages those headers under the package build prefix, so the Decypharr cross package explicitly exports that include directory through `CGO_CFLAGS` and its library directory through `CGO_LDFLAGS`.

Actual filesystem mounting is still subject to DSM/SRM runtime permissions and availability of `/dev/fuse`. The package deliberately does not run the whole Decypharr service as root merely to bypass FUSE restrictions.
