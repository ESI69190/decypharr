# Decypharr service setup for Synology DSM/SRM.
#
# Keep immutable application files below SYNOPKG_PKGDEST and persistent data
# below SYNOPKG_PKGVAR.

PATH="${SYNOPKG_PKGDEST}/bin:${PATH}"
DECYPHARR="${SYNOPKG_PKGDEST}/bin/decypharr"

HOME_DIR="${SYNOPKG_PKGVAR}"
CONFIG_DIR="${SYNOPKG_PKGVAR}/data"
CACHE_DIR="${SYNOPKG_PKGVAR}/cache"
LOG_DIR="${SYNOPKG_PKGVAR}/logs"

SERVICE_COMMAND="env PATH=${PATH} HOME=${HOME_DIR} XDG_CACHE_HOME=${CACHE_DIR} LOG_PATH=${LOG_DIR} LD_LIBRARY_PATH=${SYNOPKG_PKGDEST}/lib UMASK=022 ${DECYPHARR} --config ${CONFIG_DIR}"

SVC_BACKGROUND=y
SVC_WRITE_PID=y
SVC_WAIT_TIMEOUT=120

create_decypharr_directories()
{
    mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${LOG_DIR}"
}

configure_runtime_permissions()
{
    # External automation may rewrite config.json as root. Repair ownership
    # before every start so the unprivileged Decypharr service can still read
    # its persistent state.
    chown sc-decypharr:synocommunity "${CONFIG_DIR}" "${CACHE_DIR}" "${LOG_DIR}" 2>/dev/null || true
    for state_file in config.json auth.json torrents.json; do
        state_path="${CONFIG_DIR}/${state_file}"
        if [ -f "${state_path}" ]; then
            chown sc-decypharr:synocommunity "${state_path}" 2>/dev/null || true
            chmod 0600 "${state_path}" 2>/dev/null || true
        fi
    done
}

configure_decypharr_fuse()
{
    # DSM upgrades can drop the setuid bit on the package-local FUSE helpers.
    # Reassert the minimal permissions required by the unprivileged service.
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
    configure_runtime_permissions
    configure_decypharr_fuse
}

service_postupgrade()
{
    create_decypharr_directories
    configure_runtime_permissions
    configure_decypharr_fuse
}

service_prestart()
{
    configure_runtime_permissions
    configure_decypharr_fuse
}
