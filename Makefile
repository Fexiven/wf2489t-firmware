# WF2489T firmware: mainline U-Boot, mainline kernel (Debian packages), Debian image.
#
#   make uboot    out/uboot-copy1.img  (FIT for copy 1 of the "uboot" partition)
#   make kernel   out/kernel/*.deb     (kernel, Wi-Fi driver, linux-image-wf2489t)
#   make repo     out/repo             (apt repository: wf2489t package, kernel,
#                                       Mesa Teflon, firmware, TouchKio; signed if
#                                       WF2489T_SIGNING_KEY is set)
#   make image    out/wf2489t-debian.img, out/root.ext4 (needs /dev/kvm)
#   make all      everything
#
# Sources are fetched into build/ at the pinned versions in kernel/build.sh and
# uboot/build.sh; builds run in the container from ./Containerfile.

IMAGE   := localhost/wf2489t-build
PODMAN  := podman run --rm --userns=keep-id -e WF2489T_SIGNING_KEY -v $(CURDIR):/work:Z -w /work $(IMAGE)

.PHONY: all uboot kernel repo image container shell clean

all: uboot kernel repo image

container:
	podman build -q -t $(IMAGE) -f Containerfile .

uboot: container
	$(PODMAN) sh uboot/build.sh

kernel: container
	$(PODMAN) sh kernel/build.sh

repo: container
	$(PODMAN) sh debian/build-repo.sh

image:
	sh debian/build-image.sh

shell: container
	podman run --rm -it --userns=keep-id -v $(CURDIR):/work:Z -w /work $(IMAGE) bash

clean:
	rm -rf build out
