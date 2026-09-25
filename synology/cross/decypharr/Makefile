PKG_NAME = decypharr
PKG_VERS ?= $(DECYPHARR_GIT_HASH)
ifeq ($(strip $(PKG_VERS)),)
PKG_VERS = dev
endif
PKG_EXT = tar.gz
PKG_DIST_NAME = $(PKG_NAME)-$(PKG_VERS).$(PKG_EXT)
PKG_DIST_SITE = https://github.com/ESI69190/decypharr/archive
PKG_DIR = $(PKG_NAME)-$(PKG_VERS)

BUILD_DEPENDS = native/go
DEPENDS = cross/fuse

CGO_ENABLED = 1

REQUIRED_MIN_DSM = 7.0
REQUIRED_MIN_SRM = 1.2
UNSUPPORTED_ARCHS = $(PPC_ARCHS) $(ARMv5_ARCHS)

HOMEPAGE = https://github.com/ESI69190/decypharr
COMMENT = Media gateway for Debrid services and Usenet
LICENSE = MIT

GO_SRC_DIR = $(WORK_DIR)/$(PKG_DIR)
GO_BIN_DIR = $(GO_SRC_DIR)/decypharr

DECYPHARR_BUILD_VERSION ?= $(if $(DECYPHARR_VERSION),$(DECYPHARR_VERSION),0.0.0)
GO_BUILD_ARGS += -trimpath
GO_LDFLAGS = -s -w -X github.com/sirrobot01/decypharr/pkg/version.Version=$(DECYPHARR_BUILD_VERSION) -X github.com/sirrobot01/decypharr/pkg/version.Channel=synology

include ../../mk/spksrc.cross-go.mk
