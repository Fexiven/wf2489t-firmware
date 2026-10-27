# WF2489T firmware: Buildroot + BR2_EXTERNAL, built inside a pinned podman container.
#
#   make            build everything (output/images/)
#   make menuconfig open Buildroot's config menu (saved back with `make savedefconfig`)
#   make shell      interactive shell inside the build container
#
# Pinned inputs: the container base image (Containerfile), the Buildroot release (below),
# and everything else via the defconfig and package .hash files in external/.

BR_VERSION := 2026.02.3
BR_SHA256  := 5a59e7501b0b4ec52c41f4bfa79412320e0b37eae5f719605a258e8d0c6fc7fb
BR_TARBALL := buildroot-$(BR_VERSION).tar.xz
BR_URL     := https://buildroot.org/downloads/$(BR_TARBALL)
BR_DIR     := buildroot-$(BR_VERSION)
DEFCONFIG  := wf2489t_defconfig
IMAGE      := wf2489t-builder

TOP := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
# keep-id: files written in the container belong to the calling user; -t only when run from a terminal
TTY := $(shell test -t 0 && echo -t)
PODMAN := podman run --rm -i $(TTY) --userns=keep-id -v $(TOP):/work:Z -w /work $(IMAGE)
BR_MAKE := make -C $(BR_DIR) O=/work/output BR2_EXTERNAL=/work/external BR2_DL_DIR=/work/dl

.PHONY: all container buildroot defconfig menuconfig savedefconfig shell clean distclean

all: defconfig
	$(PODMAN) $(BR_MAKE)

container:
	podman build -t $(IMAGE) -f Containerfile .

$(BR_DIR)/Makefile:
	curl -fL -o $(BR_TARBALL) $(BR_URL)
	echo "$(BR_SHA256)  $(BR_TARBALL)" | sha256sum -c -
	tar -xf $(BR_TARBALL)
	rm -f $(BR_TARBALL)

buildroot: $(BR_DIR)/Makefile

output/.config: external/configs/$(DEFCONFIG) | buildroot container
	$(PODMAN) $(BR_MAKE) $(DEFCONFIG)

defconfig: output/.config

menuconfig: defconfig
	$(PODMAN) $(BR_MAKE) menuconfig

savedefconfig:
	$(PODMAN) $(BR_MAKE) savedefconfig BR2_DEFCONFIG=/work/external/configs/$(DEFCONFIG)

shell: container
	$(PODMAN) bash

# any Buildroot target, e.g. `make br-uboot-dirclean` or `make br-linux-menuconfig`
br-%: defconfig
	$(PODMAN) $(BR_MAKE) $*

clean:
	rm -rf output

distclean: clean
	rm -rf $(BR_DIR) dl
