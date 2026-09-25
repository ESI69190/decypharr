SPK_NAME = decypharr
SPK_VERS ?= $(if $(DECYPHARR_VERSION),$(DECYPHARR_VERSION),0.0.0)
SPK_REV ?= 1
SPK_ICON = src/decypharr.png

DEPENDS = cross/decypharr
DEPENDS += cross/rclone
DEPENDS += cross/fuse

MAINTAINER = ESI69190
MAINTAINER_URL = https://github.com/ESI69190
DESCRIPTION = Decypharr is a media gateway for Debrid services and Usenet, providing qBittorrent and SABnzbd compatible APIs for Sonarr, Radarr and other Arr applications.
DISPLAY_NAME = Decypharr
HOMEPAGE = https://github.com/ESI69190/decypharr
HELPURL = https://docs.decypharr.com
LICENSE = MIT

STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh

SERVICE_PORT = 8282
SERVICE_PORT_TITLE = Decypharr Web UI
ADMIN_PORT = $(SERVICE_PORT)

REQUIRED_MIN_DSM = 7.0
REQUIRED_MIN_SRM = 1.2
UNSUPPORTED_ARCHS = $(PPC_ARCHS) $(ARMv5_ARCHS)

USE_ALTERNATE_TMPDIR = 1

include ../../mk/spksrc.common.mk
include ../../mk/spksrc.spk.mk
