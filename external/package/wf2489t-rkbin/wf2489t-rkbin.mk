################################################################################
#
# wf2489t-rkbin
#
# Only the two blobs the U-Boot FIT needs, fetched as single files from a pinned
# rkbin commit (the full repository is several GB). Hashes in wf2489t-rkbin.hash.
#
################################################################################

WF2489T_RKBIN_VERSION = 3e288fe814e059dd06833495f845cab04ac20a5c
WF2489T_RKBIN_SITE = https://raw.githubusercontent.com/rockchip-linux/rkbin/$(WF2489T_RKBIN_VERSION)/bin/rk35
WF2489T_RKBIN_BL31 = rk3576_bl31_v1.25.elf
WF2489T_RKBIN_BL32 = rk3576_bl32_v1.12.bin
WF2489T_RKBIN_SOURCE = $(WF2489T_RKBIN_BL31)
WF2489T_RKBIN_EXTRA_DOWNLOADS = $(WF2489T_RKBIN_BL32)
WF2489T_RKBIN_LICENSE = PROPRIETARY
WF2489T_RKBIN_INSTALL_TARGET = NO
WF2489T_RKBIN_INSTALL_IMAGES = YES

define WF2489T_RKBIN_EXTRACT_CMDS
	cp $(WF2489T_RKBIN_DL_DIR)/$(WF2489T_RKBIN_BL31) $(WF2489T_RKBIN_DL_DIR)/$(WF2489T_RKBIN_BL32) $(@D)/
endef

define WF2489T_RKBIN_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/$(WF2489T_RKBIN_BL31) $(BINARIES_DIR)/rkbin/bl31.elf
	$(INSTALL) -D -m 0644 $(@D)/$(WF2489T_RKBIN_BL32) $(BINARIES_DIR)/rkbin/tee.bin
endef

$(eval $(generic-package))
