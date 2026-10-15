# Rosemary (MT6785) S-vendor: root and Droidspaces integration

**Status: experimental development. Do not flash until the feature workflow reports success and a compatible S-vendor boot image has been checked.**

Base: `ci/s-vendor-baseline` (kernel 4.14.332 from `gabutgadungan/android_kernel_xiaomi_rosemary`, branch `rosemary-13`).
Target: Redmi Note 10S (`rosemary`) with Android 12 (S) vendor. Not suitable for R-vendor layouts.

## GitHub Actions variants

| Variant | Built-in kernel features |
| --- | --- |
| `stock_droidspaces` | stock S-vendor kernel + Droidspaces options |
| `bakasu_droidspaces` | BakaSU + Droidspaces |
| `bakasu_nomount_droidspaces` | BakaSU + NoMount + Droidspaces |
| `bakasu_susfs_droidspaces` | BakaSU + SUSFS 2.3.0 + Droidspaces |
| `bakasu_susfs_nomount_droidspaces` | BakaSU + SUSFS 2.3.0 + NoMount + Droidspaces |

The default branch-push build is the full `bakasu_susfs_nomount_droidspaces` integration to stress test patch compatibility.

The **root source is BakaSU**. The old R-vendor workflow labelled some builds `resukisu`, but it ran the BakaSU setup script; do not interpret those labels as proof of a distinct ReSukiSU source.

## Droidspaces integration

Based on the official non-GKI documentation:
https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md

- IPC and POSIX queues, PID/UTS/IPC/net namespaces, seccomp filtering
- devices/cgroups, CPU/pid/memory limits, OverlayFS, tmpfs xattrs
- veth/bridge/NAT and optional IPv6/firewall options
- patched non-GKI cgroup compatibility and, if this kernel includes it, xt_qtaguid
- `CONFIG_USER_NS` is **disabled by default** because it enlarges attack surface on Linux 4.14; select `enable_userns` in the manual workflow for container sandboxing and some Docker/KDE use cases. Evaluate relevant UserNS CVE fixes before daily use.
- `CONFIG_ANDROID_PARANOID_NETWORK` is **not** changed automatically because of its impact on Android application network permissions.

**Important**: This adds kernel functionality only. The Droidspaces Android APK and Linux root filesystem are installed separately, using the original project. It is not a standalone app embedded into the kernel.

## Root, SUSFS, NoMount

Root setup and large SUSFS/compatibility patches are downloaded with revisions pinned to previously used sources. Every patch must pass a strict compatibility check; failures intentionally stop CI rather than generating a misleading ZIP. Old R-vendor changes **may not apply cleanly** and must not be forced onto this source.

For NoMount, the kernel and userspace `nm` helper must use the same Netlink protocol. The workflow supports 29 (default) or 28 (optional helper attached to the build run).

BORE remains **not implemented in this S-vendor source**. The workflow's optional `enable_bore` switch refuses to build without proper `SCHED_BORE` source/Kconfig. This avoids claiming a BORE build that doesn't contain BORE.

## Before flashing

1. Wait for a successful full-variant CI run, download the `rosemary-S-...` AnyKernel3 artifact and its `build.log` / `out/.config`.
2. Obtain a verified boot image from the working S-vendor ROM and record whether the device expects `Image.gz` or `Image.gz-dtb`.
3. Keep original `boot.img` and a tested recovery method. Do **not** flash the kernel on the older R-vendor layout.
4. Only after testing boot: check Droidspaces Requirements, NoMount userspace protocol, TEE/fingerprint, video decoding, Bluetooth, and `dmesg`.
5. If the kernel fails to boot, restore the original known-good `boot.img`.

## Provenance

- BakaSU: https://github.com/Baka-SU/BakaSU
- SUSFS hooks / compat adaptations: existing R-vendor fork `vildangil/android_kernel_xiaomi_rosemary`
- NoMount Suite: https://github.com/Bouteillepleine/NoMount-Suite
- Droidspaces: https://github.com/ravindu644/Droidspaces-OSS
