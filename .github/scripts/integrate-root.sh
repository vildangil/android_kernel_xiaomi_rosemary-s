#!/usr/bin/env bash
set -euo pipefail

# Port of the working R-vendor BakaSU integration to S-vendor 4.14.
# The patch set must pass git apply --check; no fuzzy or silent patching.
ROOT_REV="09e3a82adfb12233171ffbf13028f0f62640706b"
OLD="https://raw.githubusercontent.com/vildangil/android_kernel_xiaomi_rosemary/${ROOT_REV}/.github/patches"
BAKASU_REV="d7260ca1e5c128061122924d0d48754e361e135c"
mkdir -p /tmp/rosemary-root

curl -fL --retry 3 "https://raw.githubusercontent.com/Baka-SU/BakaSU/${BAKASU_REV}/kernel/setup.sh" -o /tmp/rosemary-root/bakasu-setup.sh
bash /tmp/rosemary-root/bakasu-setup.sh

apply_checked() {
  local name="$1"
  curl -fL --retry 3 "${OLD}/${name}" -o "/tmp/rosemary-root/${name}"
  if ! git apply --check "/tmp/rosemary-root/${name}"; then
    echo "::error::${name} was made for R-vendor and does not apply to the S-vendor tree."
    echo "::error::Do not ship an unverified root-enabled kernel; adapt the hooks first."
    exit 1
  fi
  git apply "/tmp/rosemary-root/${name}"
}
apply_checked "bakasu-susfs-rosemary-sucompat.patch"
apply_checked "bakasu-manual-hooks-4.14.patch"

test -f drivers/kernelsu/Kconfig
grep -q 'CONFIG_KSU' drivers/Makefile

if [[ "${BUILD_VARIANT:-}" == *susfs* ]]; then
  # fdinfo.c on S-vendor uses fsnotify connector-based marks, unlike the R-vendor
  # source used to produce the original SUSFS patch. Its KSTAT handling is ported
  # directly into fs/notify/fdinfo.c in this branch; omit ONLY that obsolete hunk.
  curl -fL --retry 3 "${OLD}/susfs-2.3.0-rosemary.patch" -o /tmp/rosemary-root/susfs-r-original.patch
  awk '
    /^diff --git a\/fs\/notify\/fdinfo.c b\/fs\/notify\/fdinfo.c/ { skip=1; next }
    /^diff --git / && skip { skip=0 }
    !skip { print }
  ' /tmp/rosemary-root/susfs-r-original.patch > /tmp/rosemary-root/susfs-2.3.0-rosemary.patch
  test -s /tmp/rosemary-root/susfs-2.3.0-rosemary.patch
  if ! git apply --check /tmp/rosemary-root/susfs-2.3.0-rosemary.patch; then
    echo "::error::Remaining SUSFS 2.3.0 patch conflicts with this S-vendor tree."
    exit 1
  fi
  git apply /tmp/rosemary-root/susfs-2.3.0-rosemary.patch
  grep -q 'susfs_sus_kstat_spoof_inotify_fdinfo' fs/notify/fdinfo.c
  test -s fs/susfs.c
  test -s include/linux/susfs.h
  test -s include/linux/susfs_def.h
  grep -Fqx '#define SUSFS_VERSION "v2.3.0"' include/linux/susfs.h
  for item in \
    'kernel/sys.c:ksu_handle_setresuid' \
    'fs/read_write.c:ksu_handle_sys_read' \
    'drivers/input/input.c:ksu_handle_input_handle_event' \
    'fs/exec.c:ksu_handle_execveat' \
    'fs/open.c:ksu_handle_faccessat' \
    'fs/stat.c:ksu_handle_stat' \
    'kernel/reboot.c:ksu_handle_sys_reboot'; do
    grep -Fq "${item#*:}" "${item%%:*}" || {
      echo "::error::Missing SUSFS inline hook ${item}"
      exit 1
    }
  done
fi
