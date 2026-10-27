################################################################################
#
# wf2489t-aic8800
#
################################################################################

WF2489T_AIC8800_VERSION = fce88024ed40279def034e203128e0892fdbcac3
WF2489T_AIC8800_SITE = $(call github,radxa-pkg,aic8800,$(WF2489T_AIC8800_VERSION))
WF2489T_AIC8800_LICENSE = GPL-3.0
WF2489T_AIC8800_LICENSE_FILES = LICENSE
WF2489T_AIC8800_MODULE_SUBDIRS = src/SDIO/driver_fw/driver/aic8800

# Radxa's own fixes (newer kernels, firmware path /lib/firmware/aic8800_fw/SDIO/<chip>),
# reduced to the SDIO driver that is built here; numbered to keep their series order
define WF2489T_AIC8800_APPLY_RADXA_PATCHES
	mkdir -p $(@D)/sdio-patches
	n=0; for p in $$(cat $(@D)/debian/patches/series); do \
		n=$$((n + 1)); out=$(@D)/sdio-patches/$$(printf %04d $$n)-$$p; \
		$(HOST_DIR)/bin/python3 $(WF2489T_AIC8800_PKGDIR)/sdio-only.py \
			$(@D)/debian/patches/$$p > $$out || exit 1; \
		test -s $$out || rm $$out; \
	done
	$(APPLY_PATCHES) $(@D) $(@D)/sdio-patches \*.patch
endef
WF2489T_AIC8800_DEPENDENCIES = host-python3
WF2489T_AIC8800_POST_PATCH_HOOKS += WF2489T_AIC8800_APPLY_RADXA_PATCHES

# firmware for the AIC8800D80 only
define WF2489T_AIC8800_INSTALL_FIRMWARE
	mkdir -p $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO
	cp -a $(@D)/src/SDIO/driver_fw/fw/aic8800D80 $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO/
endef
WF2489T_AIC8800_POST_INSTALL_TARGET_HOOKS += WF2489T_AIC8800_INSTALL_FIRMWARE

$(eval $(kernel-module))
$(eval $(generic-package))
