#!/usr/bin/env bash
set -euo pipefail

PROTO="${NOMOUNT_NETLINK_PROTO:-29}"
case "${PROTO}" in 28|29) ;; *) echo "::error::Invalid NoMount Netlink protocol"; exit 1;; esac

git clone --depth=1 https://github.com/Bouteillepleine/NoMount-Suite.git /tmp/rosemary-nomount
git -C /tmp/rosemary-nomount checkout --detach f75cd19096b859f7c20181402231dad914bb02f7

if [[ "${PROTO}" == "28" ]]; then
  for hdr in /tmp/rosemary-nomount/hookless/src/nomount.h /tmp/rosemary-nomount/userspace/src/nm.h; do
    sed -i -E "s/(#define NOMOUNT_NL_PROTO[[:space:]]+)29$/\\1${PROTO}/" "${hdr}"
  done
  ../clang-proton/bin/clang --target=aarch64-linux-android26 -Oz -static -nostdlib \
    -fuse-ld=lld -ffreestanding -fno-unwind-tables -fno-ident \
    -Wno-invalid-noreturn -Wl,--entry=_start \
    /tmp/rosemary-nomount/userspace/src/nm.c \
    -o "nomount-nm-proto${PROTO}-arm64"
  readelf -h "nomount-nm-proto${PROTO}-arm64" | grep -q AArch64
fi

for hdr in /tmp/rosemary-nomount/hookless/src/nomount.h /tmp/rosemary-nomount/userspace/src/nm.h; do
  grep -qE "^#define NOMOUNT_NL_PROTO[[:space:]]+${PROTO}$" "${hdr}"
done

cp /tmp/rosemary-nomount/hookless/src/nomount.c fs/nomount.c
cp /tmp/rosemary-nomount/hookless/src/nomount.h fs/nomount.h
# SUSFS rewrites show_map_vma() in task_mmu.c, so the default unified
# hunk for this same function cannot apply. Adapt that hunk separately.
awk '
  /^diff --git a\/fs\/proc\/task_mmu.c b\/fs\/proc\/task_mmu.c/ { skip=1; next }
  /^diff --git / && skip { skip=0 }
  !skip { print }
' /tmp/rosemary-nomount/hookless/patches/nomount_kernel_integration.patch \
  > /tmp/rosemary-nomount/integration-s-vendor.patch

if ! patch -p1 --dry-run --fuzz=0 < /tmp/rosemary-nomount/integration-s-vendor.patch; then
  echo "::error::NoMount Kconfig/Makefile patch conflicts with S-vendor."
  exit 1
fi
patch -p1 --fuzz=0 < /tmp/rosemary-nomount/integration-s-vendor.patch
python3 .github/scripts/patch-nomount-maps.py
grep -q 'config NOMOUNT' fs/Kconfig
grep -q 'CONFIG_NOMOUNT' fs/Makefile
grep -q 'vfs_map_meta_override' fs/proc/task_mmu.c
