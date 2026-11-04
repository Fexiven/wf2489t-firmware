#!/bin/sh
# The wf2489t package (board support + kiosk) from package/root and
# package/DEBIAN. Version: date of the last commit that changed package/.
# Output: out/repo/wf2489t_VERSION_all.deb
set -eu
cd "$(dirname "$0")/.."
VERSION=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d.%H%M -- package)
[ -n "$VERSION" ] || { echo "commit package/ first"; exit 1; }
P=build/wf2489t-pkg
rm -rf $P && mkdir -p $P out/repo
cp -a package/root/. $P/
cp -a package/DEBIAN $P/
sed -i "2i Version: $VERSION" $P/DEBIAN/control
chmod 755 $P/DEBIAN/postinst $P/DEBIAN/prerm $P/DEBIAN/postrm $P/usr/libexec/wf2489t/*
chmod 440 $P/etc/sudoers.d/wf2489t
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct -- package)
rm -f out/repo/wf2489t_*.deb
dpkg-deb --root-owner-group -Zxz --build $P out/repo/wf2489t_${VERSION}_all.deb >/dev/null
echo out/repo/wf2489t_${VERSION}_all.deb
