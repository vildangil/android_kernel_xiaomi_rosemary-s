#!/usr/bin/env bash
set -euo pipefail

# Droidspaces non-GKI fixes from ravindu644/Droidspaces-OSS
# Pinned so CI does not silently pick up changed kernel patches.
DROIDSPACES_REV="0aa20da53656790aee4747537bfacb301b165aec"
ROOT="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/${DROIDSPACES_REV}/Documentation/resources/kernel-patches/non-GKI"
mkdir -p /tmp/rosemary-droidspaces
curl -fL --retry 3 "${ROOT}/01.fix_kernel_panic_in_xt_qtaguid.patch" -o /tmp/rosemary-droidspaces/01-qtaguid.patch
curl -fL --retry 3 "${ROOT}/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch" -o /tmp/rosemary-droidspaces/02-cgroup.patch

for fix in /tmp/rosemary-droidspaces/01-qtaguid.patch /tmp/rosemary-droidspaces/02-cgroup.patch; do
  echo "Droidspaces: testing ${fix}"
  git apply --check "${fix}" || {
    echo "::error::Droidspaces fix cannot be applied to this S-vendor source. Adapt it; do not silently ignore."
    exit 1
  }
  git apply "${fix}"
done
echo "Droidspaces non-GKI kernel fixes applied."
