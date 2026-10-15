#!/usr/bin/env bash
set -euo pipefail

# Android 12 S-vendor, Linux 4.14 (non-GKI).
# Follow ravindu644/Droidspaces-OSS/Documentation/Kernel-Configuration.md.
# This modifies the build's out/.config, not the original vendor-defconfig.
CFG=out/.config
make O=out ARCH=arm64 rosemary_defconfig
test -s "$CFG"

enable() { for option in "$@"; do scripts/config --file "$CFG" -e "$option"; done; }
disable() { for option in "$@"; do scripts/config --file "$CFG" -d "$option"; done; }
required=(
  SYSCTL SYSVIPC POSIX_MQUEUE
  NAMESPACES PID_NS UTS_NS IPC_NS
  SECCOMP SECCOMP_FILTER
  CGROUPS CGROUP_DEVICE CGROUP_SCHED FAIR_GROUP_SCHED CGROUP_FREEZER CGROUP_NET_PRIO
  MEMCG CFS_BANDWIDTH CGROUP_PIDS CGROUP_CPUACCT
  DEVTMPFS OVERLAY_FS
  TMPFS_POSIX_ACL TMPFS_XATTR
  NET_NS VETH BRIDGE NETFILTER BRIDGE_NETFILTER NETFILTER_ADVANCED
  NF_CONNTRACK IP_NF_IPTABLES IP_NF_FILTER NF_NAT NF_TABLES
  IP_NF_TARGET_MASQUERADE
  # No separate NETFILTER_XT_TARGET_MASQUERADE symbol in this 4.14 tree.
  NETFILTER_XT_TARGET_TCPMSS NETFILTER_XT_MATCH_ADDRTYPE
  NF_CONNTRACK_NETLINK NF_NAT_REDIRECT
  IP_ADVANCED_ROUTER IP_MULTIPLE_TABLES
)
enable "${required[@]}"

# Kernel 4.14 legacy compatibility and optional Linux container features.
optional=(
  NF_CONNTRACK_IPV4 NF_NAT_IPV4 IP_NF_NAT
  IPV6 IPV6_MULTIPLE_TABLES IP6_NF_IPTABLES IP6_NF_FILTER
  IP6_NF_MANGLE IP6_NF_NAT IP6_NF_TARGET_MASQUERADE
  NF_CONNTRACK_IPV6 NF_NAT_IPV6
  MACVLAN FUSE_FS TUN
  NETFILTER_XT_TARGET_REJECT NETFILTER_XT_TARGET_LOG
  NETFILTER_XT_MATCH_RECENT
  IP_SET IP_SET_HASH_IP IP_SET_HASH_NET NETFILTER_XT_SET
  BLK_DEV_LOOP EXT4_FS
)
enable "${optional[@]}"

if [[ "${ENABLE_USERNS:-false}" == "true" ]]; then
  enable USER_NS
else
  disable USER_NS
fi

if [[ "${BUILD_VARIANT:-stock_droidspaces}" != "stock_droidspaces" ]]; then
  enable KSU KALLSYMS DEBUG_KERNEL KALLSYMS_ALL
  if [[ "${BUILD_VARIANT}" == *susfs* ]]; then
    disable KSU_MANUAL_HOOK
    enable KSU_SUSFS
    enable \
      KSU_SUSFS_SUS_PATH KSU_SUSFS_SUS_MOUNT KSU_SUSFS_SUS_KSTAT \
      KSU_SUSFS_SPOOF_UNAME KSU_SUSFS_ENABLE_LOG KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
      KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG KSU_SUSFS_OPEN_REDIRECT \
      KSU_SUSFS_SUS_MAP
  else
    enable KSU_MANUAL_HOOK
  fi
  if [[ "${BUILD_VARIANT}" == *nomount* ]]; then
    enable NOMOUNT
  fi
fi

if [[ "${ENABLE_BORE:-false}" == "true" ]]; then
  # The original R-vendor tree had BORE; the S-vendor tree may need the source port.
  if grep -Rq 'config SCHED_BORE' kernel/Kconfig* init/Kconfig 2>/dev/null; then
    enable SCHED_BORE
  else
    echo "::error::BORE sources are absent from the current S-vendor tree. Port code before enabling."
    exit 1
  fi
fi

make O=out ARCH=arm64 olddefconfig
check_y() {
  for option in "$@"; do
    if ! grep -qx "CONFIG_${option}=y" "$CFG"; then
      echo "::error::CONFIG_${option}=y did not survive olddefconfig. Verify Kconfig dependencies."
      exit 1
    fi
  done
}
check_y "${required[@]}"
check_y MACH_MT6785 VIDEO_MEDIATEK_VCODEC MICROTRUST_TEE_SUPPORT MTK_TEE_GP_SUPPORT GOODIX_FINGERPRINT FPC_FINGERPRINT
if [[ "${ENABLE_USERNS:-false}" == "true" ]]; then check_y USER_NS; fi
if [[ "${BUILD_VARIANT:-stock_droidspaces}" != "stock_droidspaces" ]]; then
  check_y KSU KALLSYMS_ALL
  if [[ "${BUILD_VARIANT}" == *susfs* ]]; then
    check_y KSU_SUSFS
  else
    check_y KSU_MANUAL_HOOK
  fi
  if [[ "${BUILD_VARIANT}" == *nomount* ]]; then check_y NOMOUNT; fi
fi
if [[ "${ENABLE_BORE:-false}" == "true" ]]; then check_y SCHED_BORE; fi

# Verify critical vendor features have not been flipped by olddefconfig.
echo "===== S vendor, root, Droidspaces important configuration ====="
grep -E '^CONFIG_(MACH_MT6785|VIDEO_MEDIATEK_VCODEC|MICROTRUST_TEE_SUPPORT|MTK_TEE_GP_SUPPORT|GOODIX_FINGERPRINT|FPC_FINGERPRINT|KSU|KSU_SUSFS|NOMOUNT|SYSVIPC|PID_NS|IPC_NS|USER_NS|DEVTMPFS|VETH|NET_NS|OVERLAY_FS|LOCALVERSION)=' "$CFG" || true
