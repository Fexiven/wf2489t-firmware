#!/bin/sh
# wf2489t-person-runtime: what the person sensor (wf2489t-person.service) needs
# besides the NPU delegate (mesa-teflon-rk3576), called by debian/build-repo.sh:
#   /usr/lib/wf2489t/python/ai_edge_litert  LiteRT (TensorFlow Lite) interpreter from
#       Google's PyPI wheel, pinned; only the interpreter and its one library (the
#       wheel has no Debian package; Debian's python3-numpy is used)
#   /usr/share/wf2489t/efficientdet_lite0_int8.tflite  EfficientDet-Lite0 (COCO,
#       int8), the copy in Mesa's Teflon tests (mesa-26.2.6), pinned
# Version: date of the last commit that changed person/.
# Output: out/repo/wf2489t-person-runtime_VERSION_arm64.deb
set -eu
cd "$(dirname "$0")/.."
VERSION=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d.%H%M -- person)
[ -n "$VERSION" ] || { echo "commit person/ first"; exit 1; }
LITERT=ai_edge_litert-2.3.0-cp313-cp313-manylinux_2_27_aarch64.whl
LITERT_URL=https://files.pythonhosted.org/packages/b2/ad/234674ab4781ff1822c26794488b5640512bc61011a6b3490bfecdc46aa1/$LITERT
LITERT_SHA256=2ab71e4f5dfa65b3882634b42755f455f3e7415630d720200bd792733e15e257
MODEL=efficientdet_tflite_lite0_int8_v1.tflite
MODEL_URL=https://gitlab.freedesktop.org/mesa/mesa/-/raw/mesa-26.2.6/src/gallium/targets/teflon/tests/models/efficientdet/$MODEL
MODEL_SHA256=33a3b622c7cac0762f96089353cd61495f3e993968d133af7871bfc2d5396704

mkdir -p build/dl
[ -f build/dl/$LITERT ] || curl -sSfL -o build/dl/$LITERT $LITERT_URL
[ -f build/dl/$MODEL ] || curl -sSfL -o build/dl/$MODEL $MODEL_URL
echo "$LITERT_SHA256  build/dl/$LITERT" | sha256sum -c --quiet
echo "$MODEL_SHA256  build/dl/$MODEL" | sha256sum -c --quiet

P=build/person-pkg L=usr/lib/wf2489t/python/ai_edge_litert D=usr/share/doc/wf2489t-person-runtime
rm -rf $P && mkdir -p $P/DEBIAN $P/$L $P/usr/share/wf2489t $P/$D out/repo
python3 - build/dl/$LITERT $P/$L <<'PY'
import sys, zipfile
keep = ("__init__.py", "interpreter.py", "metrics_interface.py", "metrics_portable.py",
        "_pywrap_litert_interpreter_wrapper.so", "libpywrap_litert_common.so")
z = zipfile.ZipFile(sys.argv[1])
for f in keep:
    open(f"{sys.argv[2]}/{f}", "wb").write(z.read(f"ai_edge_litert/{f}"))
open(sys.argv[2] + "/LICENSE", "wb").write(z.read("ai_edge_litert-2.3.0.dist-info/licenses/LICENSE"))
PY
chmod 644 $P/$L/*
install -m 644 build/dl/$MODEL $P/usr/share/wf2489t/efficientdet_lite0_int8.tflite
mv $P/$L/LICENSE $P/$D/
{ printf 'ai_edge_litert 2.3.0 (%s), interpreter only.\n' $LITERT
  printf 'EfficientDet-Lite0 int8 (Google, TensorFlow Hub/Kaggle), Apache-2.0, via Mesa 26.2.6:\n%s\n\n' $MODEL_URL
  cat $P/$D/LICENSE; } > $P/$D/copyright
rm $P/$D/LICENSE
cat > $P/DEBIAN/control <<CONTROL
Package: wf2489t-person-runtime
Version: $VERSION
Architecture: arm64
Maintainer: wf2489t-firmware
Depends: python3 (>= 3.13), python3 (<< 3.14), python3-numpy, libc6, libstdc++6, libgcc-s1
Section: misc
Priority: optional
Description: LiteRT interpreter and person detection model for the WF2489T
 The TensorFlow Lite (LiteRT 2.3.0) interpreter from Google's wheel and the
 EfficientDet-Lite0 int8 model, for the person sensor of the wf2489t package.
 The model runs on the NPU through mesa-teflon-rk3576.
CONTROL
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct -- person)
rm -f out/repo/wf2489t-person-runtime_*.deb
dpkg-deb --root-owner-group -Zxz --build $P out/repo/wf2489t-person-runtime_${VERSION}_arm64.deb >/dev/null
echo out/repo/wf2489t-person-runtime_${VERSION}_arm64.deb
