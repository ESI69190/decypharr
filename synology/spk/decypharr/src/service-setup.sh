# Decypharr service setup for Synology DSM/SRM.
#
# Keep immutable application files below SYNOPKG_PKGDEST and persistent data
# below SYNOPKG_PKGVAR, following the same layout used by SynoCommunity
# packages such as Bazarr, Sonarr and Radarr.

PATH="${SYNOPKG_PKGDEST}/bin:${PATH}"
DECYPHARR="${SYNOPKG_PKGDEST}/bin/decypharr"

HOME_DIR="${SYNOPKG_PKGVAR}"
CONFIG_DIR="${SYNOPKG_PKGVAR}/data"
CACHE_DIR="${SYNOPKG_PKGVAR}/cache"
LOG_DIR="${SYNOPKG_PKGVAR}/logs"

SERVICE_COMMAND="env PATH=${PATH} HOME=${HOME_DIR} XDG_CACHE_HOME=${CACHE_DIR} LOG_PATH=${LOG_DIR} LD_LIBRARY_PATH=${SYNOPKG_PKGDEST}/lib DECYPHARR_SYNOLOGY_FUSE_COMPAT=1 UMASK=022 ${DECYPHARR} --config ${CONFIG_DIR}"

SVC_BACKGROUND=y
SVC_WRITE_PID=y
SVC_WAIT_TIMEOUT=120

create_decypharr_directories()
{
    mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${LOG_DIR}"
}

configure_decypharr_fuse()
{
    # DSM installs package files without preserving the privileged mode required
    # by libfuse helpers. Restore it every time the package is installed,
    # upgraded or started so Decypharr never falls back to "running without mount".
    fuse_conf="${SYNOPKG_PKGDEST}/etc/fuse.conf"

    if [ -d "${SYNOPKG_PKGDEST}/etc" ]; then
        chmod 0755 "${SYNOPKG_PKGDEST}/etc" 2>/dev/null || true
    fi
    if [ -f "${fuse_conf}" ]; then
        chmod 0644 "${fuse_conf}" 2>/dev/null || true
    fi

    for helper in fusermount fusermount3; do
        helper_path="${SYNOPKG_PKGDEST}/bin/${helper}"
        if [ -f "${helper_path}" ]; then
            chown root:root "${helper_path}" 2>/dev/null || true
            chmod 4755 "${helper_path}" 2>/dev/null || true
        fi
    done

    if [ -e /dev/fuse ]; then
        chmod 0666 /dev/fuse 2>/dev/null || true
    fi
}

service_postinst()
{
    create_decypharr_directories
    configure_decypharr_fuse
}

service_postupgrade()
{
    # SYNOPKG_PKGVAR survives package upgrades. Re-create only directories
    # introduced by newer package revisions.
    create_decypharr_directories
    configure_decypharr_fuse
}

service_prestart()
{
    # Reassert FUSE runtime permissions before every service start/restart.
    configure_decypharr_fuse
}
