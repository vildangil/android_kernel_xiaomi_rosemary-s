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

**S-vendor fingerprint conflict fixed in the build configuration:** Goodix fingerprint uses `GF_NETLINK_ROUTE 29` in both `drivers/input/fingerprint/goodix/gf_spi_tee.c` and `drivers/input/fingerprint_C3J/goodix/gf_spi_tee.c`. The kernel NoMount source also defaults to `NOMOUNT_NL_PROTO 29`, which can prevent the fingerprint daemon from establishing its callback. The S-vendor CI now **forces NoMount Netlink protocol 28** and explicitly rejects 29 without modifying the fingerprint driver.

**The kernel and NoMount userspace `nm` binary must both use protocol 28.** Each NoMount build uploads `nomount-nm-proto28-arm64` as a separate artifact, to be deployed as the matching userspace client in the installed NoMount environment. An existing stock NoMount userspace client compiled for 29 will not communicate with the 28 kernel. Verify where your installed `nm` binary lives before replacing it and keep a backup. Do not blindly overwrite the manager's main `nomount` executable or rebuild its entire module without inspecting its paths.

Log evidence from the affected device: `Fingerprint21: Fingerprint HAL ready, HAL ID: 0` followed by repeated `Unable to set callback`. This supports but does not by itself prove the collision was the only fingerprint issue; retest on the updated kernel.

The separate 'white noise on lock screen' display issue is **not established as a NoMount/netlink problem**. Confirm whether it occurs on an unmodified S-vendor kernel and capture kernel `dmesg`/drm/HWC traces before making display-driver changes.

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
