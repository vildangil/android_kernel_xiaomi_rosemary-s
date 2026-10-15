# Rosemary S-vendor baseline

This branch introduces the **stock baseline only** for Redmi Note 10S / POCO M5s (`rosemary`, MT6785) with Android 12 (S) vendor.

## Source and build

- Original upstream: `gabutgadungan/android_kernel_xiaomi_rosemary` branch `rosemary-13`.
- Defconfig: `arch/arm64/configs/rosemary_defconfig` (unchanged).
- Toolchain: Proton Clang, following the original `b.sh`.
- Output: `out/arch/arm64/boot/Image.gz`, packed into AnyKernel3 from the existing `vildangil/BlackSide_Kernel_AnyKernel3` rosemary branch.
- S-vendor variant: no KernelSU, ReSukiSU, SUSFS, NoMount, or BORE patches at this stage.

## How to build

Open the repository **Actions** tab, select **Rosemary S-vendor - baseline kernel**, and run the workflow once it is available on the default branch. Builds on the `ci/s-vendor-baseline` branch also run on pushes, and PRs targeting `rosemary-13` trigger the check.

Download `rosemary-S-stock-<run_number>` from the successful run's **Artifacts**.

## Safety / scope

**Experimental, untested on actual S-vendor ROM.** The CI compile and the ability to flash/boot are different checks.

- Keep a verified recovery method and a backup of your currently working `boot.img`.
- Do not flash on R-vendor firmware; test only with the intended S vendor.
- This is a kernel-only AnyKernel3 package, not a complete `boot.img`.
- No vendor blobs, partitions, TEE binaries, or fingerprint files are replaced by the workflow.
- ZIP packaging follows the original S-vendor `b.sh`, which uses `Image.gz`, but uses the existing rosemary AnyKernel3 script. Verify device's boot image layout before flashing.
- If the boot image is incompatible, restore the original `boot.img` via fastboot/recovery.

## Planned feature porting (after baseline boot test)

1. Preserve stock fingerprint / Microtrust TEE / video drivers.
2. Add root variants using the previous R-vendor workflow as *reference*, not as an unverified copy of R-vendor patches.
3. Port SUSFS 2.3.0 with version and hook checks.
4. Port NoMount with consistent kernel/userspace Netlink protocol.
5. Keep BORE optional; enable only after validating a working configuration.
6. Compare dmesg for VDEC, SurfaceFlinger, Bluetooth and fingerprint behavior on S vendor.

Work on a separate integration branch to keep `rosemary-13` and this baseline recoverable.
