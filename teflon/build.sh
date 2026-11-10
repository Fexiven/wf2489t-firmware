#!/bin/sh
# mesa-teflon-rk3576: Mesa's Teflon TensorFlow Lite delegate with the rocket
# driver for the RK3576 NPU (runs in the build container, called by
# debian/build-repo.sh). Temporary, until RK3576 support is in Mesa: Jiaxing
# Hu's development tree (gahingwoo/mesa-rk3576) + teflon/patches/ from
# github.com/Fexiven/rk3576-npu-open (mesa/, unchanged copies).
# Installs /usr/lib/teflon-rk3576/libteflon.so (Debian's own
# mesa-teflon-delegate has /usr/lib/teflon/libteflon.so, no conflict).
# Version: date of the last commit that changed teflon/.
# Output: out/repo/mesa-teflon-rk3576_VERSION_arm64.deb
set -eu
cd "$(dirname "$0")/.."
REPO=https://github.com/gahingwoo/mesa-rk3576
COMMIT=1f0de937b71119c50461fdbcdfd8b2f8a38e232c
VERSION=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d.%H%M -- teflon)
[ -n "$VERSION" ] || { echo "commit teflon/ first"; exit 1; }

SRC=build/mesa OBJ=build/mesa-obj
if [ ! -d $SRC/.git ]; then
	git init -q $SRC
	git -C $SRC fetch -q --depth 1 $REPO $COMMIT
fi
# pristine tree + patches (unchanged files keep their mtime: incremental rebuilds)
git -C $SRC checkout -q --detach $COMMIT
git -C $SRC reset -q --hard
git -C $SRC clean -q -fdx
for p in teflon/patches/*.patch; do git -C $SRC apply "$PWD/$p"; done

export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct -- teflon)
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
[ -f $OBJ/build.ninja ] || meson setup $OBJ $SRC --cross-file teflon/aarch64.ini \
	-Dbuildtype=release -Dgallium-drivers=rocket -Dteflon=true -Dvulkan-drivers= -Dplatforms= \
	-Dglx=disabled -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dllvm=disabled
ninja -C $OBJ src/gallium/targets/teflon/libteflon.so

P=build/teflon-pkg D=usr/share/doc/mesa-teflon-rk3576
rm -rf $P && mkdir -p $P/DEBIAN $P/usr/lib/teflon-rk3576 $P/$D out/repo
aarch64-linux-gnu-strip --strip-unneeded -o $P/usr/lib/teflon-rk3576/libteflon.so \
	$OBJ/src/gallium/targets/teflon/libteflon.so
{ printf 'Mesa %s (%s) + teflon/patches/ (github.com/Fexiven/rk3576-npu-open, mesa/).\n\n' $COMMIT $REPO
  cat $SRC/docs/license.rst; } > $P/$D/copyright
cat > $P/DEBIAN/control <<CONTROL
Package: mesa-teflon-rk3576
Version: $VERSION
Architecture: arm64
Maintainer: wf2489t-firmware
Depends: libc6 (>= 2.38), libdrm2, libexpat1
Section: libs
Priority: optional
Description: Mesa Teflon TensorFlow Lite delegate for the RK3576 NPU
 Mesa's Teflon delegate with the rocket driver and the RK3576 patches from
 rk3576-npu-open, until they are in Mesa. Needs the rocket kernel driver
 (linux-image-wf2489t). Load /usr/lib/teflon-rk3576/libteflon.so as an
 external delegate in TensorFlow Lite / LiteRT.
CONTROL
rm -f out/repo/mesa-teflon-rk3576_*.deb
dpkg-deb --root-owner-group -Zxz --build $P out/repo/mesa-teflon-rk3576_${VERSION}_arm64.deb >/dev/null
echo out/repo/mesa-teflon-rk3576_${VERSION}_arm64.deb
