#!/usr/bin/env bash
set -euo pipefail

# Droidspaces non-GKI fixes from ravindu644/Droidspaces-OSS
# Pinned so CI does not silently pick up changed kernel patches.
DROIDSPACES_REV="0aa20da53656790aee4747537bfacb301b165aec"
ROOT="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/${DROIDSPACES_REV}/Documentation/resources/kernel-patches/non-GKI"
mkdir -p /tmp/rosemary-droidspaces
curl -fL --retry 3 "${ROOT}/01.fix_kernel_panic_in_xt_qtaguid.patch" -o /tmp/rosemary-droidspaces/01-qtaguid.patch
curl -fL --retry 3 "${ROOT}/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch" -o /tmp/rosemary-droidspaces/02-cgroup.patch

# Some Android vendor kernels do not ship the legacy xt_qtaguid source.
# Its crash workaround is irrelevant when the affected driver is absent.
if [[ -f net/netfilter/xt_qtaguid.c ]]; then
  git apply --check /tmp/rosemary-droidspaces/01-qtaguid.patch || {
    echo "::error::Droidspaces qtaguid patch conflicts with this kernel."
    exit 1
  }
  git apply /tmp/rosemary-droidspaces/01-qtaguid.patch
else
  echo "::notice::xt_qtaguid is absent, so its Droidspaces crash workaround is not applicable."
fi

git apply --check /tmp/rosemary-droidspaces/02-cgroup.patch || {
  echo "::error::Droidspaces cgroup compatibility fix requires adaptation for this vendor tree."
  exit 1
}
git apply /tmp/rosemary-droidspaces/02-cgroup.patch
echo "Droidspaces non-GKI fixes checked/applied."
