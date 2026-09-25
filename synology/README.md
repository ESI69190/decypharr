# Decypharr for Synology DSM 7.x and SRM 1.x

This directory contains a SynoCommunity **spksrc overlay** for building Decypharr as a native Synology package (`.spk`).

The package layout follows the same model as the SynoCommunity packages for Bazarr, Sonarr and Radarr:

- `SERVICE_USER = auto` creates a dedicated Synology service account.
- Application binaries live below `SYNOPKG_PKGDEST`.
- Persistent configuration, cache and logs live below `SYNOPKG_PKGVAR`.
- DSM/SRM controls the process through `service-setup.sh`.
- Port 8282 is exposed as the administration link.
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

The package account is managed by Synology, normally as `sc-decypharr`. Give that account access to the shared folders Decypharr, Sonarr or Radarr must read.

## Supported package architectures

The CI intentionally targets the Synology package architectures requested for DSM 7.x and SRM 1.x.

### DSM 7.x

All DSM packages are built against DSM 7.1-compatible spksrc toolchains:

```text
apollolake
avoton
braswell
broadwell
broadwellnk
broadwellnkv2
broadwellntbap
bromolow
cedarview
denverton
epyc7002
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
armada370
armada375
armada38x
armadaxp
monaco
armada37xx
rtd1296
rtd1619b
evansport
```

For `geminilakenk`, `icelaked`, `r1000nk` and `v1000nk`, spksrc does not provide a dedicated DSM 7.1 toolchain directory. Those packages therefore compile with the DSM 7.1 generic `x64` toolchain, whose architecture list explicitly includes those platforms, while `SPK_PACKAGE_ARCHS` restricts the generated package metadata to the requested platform.

### SRM 1.x

SRM packages are built with the SRM 1.3 toolchains:

```text
dakota
ipq806x
cypress
```

## CI behavior

The workflow first performs a complete DSM 7.1 `apollolake` smoke build. The remaining architecture matrix starts only after that package succeeds. This prevents a common packaging error from wasting the entire matrix.

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
DECYPHARR_VERSION="0.0.0-dev" \
make -C .synology-build/spksrc/spk/decypharr \
  arch-apollolake-7.1 \
  SPK_PACKAGE_ARCHS=apollolake
```

The generated package is written below:

```text
.synology-build/spksrc/packages/
```

## CGO and FUSE

Decypharr uses `github.com/winfsp/cgofuse`. On Linux it expects the FUSE 2 headers. The spksrc `cross/fuse` dependency stages those headers under the package build prefix, so the Decypharr cross package explicitly exports that include directory through `CGO_CFLAGS` and its library directory through `CGO_LDFLAGS`.

Actual filesystem mounting is still subject to DSM/SRM runtime permissions and availability of `/dev/fuse`. The package deliberately does not run the whole Decypharr service as root merely to bypass FUSE restrictions.
