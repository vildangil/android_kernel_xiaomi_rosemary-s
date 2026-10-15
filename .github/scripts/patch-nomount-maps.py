#!/usr/bin/env python3
"""Insert NoMount map metadata hook into the final S-vendor task_mmu.c.

Run AFTER the SUSFS patch; both features modify show_map_vma() and independent
unified hunks conflict. Refuse unexpected kernel layouts instead of guessing.
"""
from pathlib import Path

path = Path("fs/proc/task_mmu.c")
source = path.read_text()
anchor = "static void\nshow_map_vma("
if source.count(anchor) != 1:
    raise SystemExit("Unexpected show_map_vma declaration; NoMount integration stopped")
before, after = source.split(anchor, 1)
terminator = "\n\tstart = vma->vm_start;"
if terminator not in after:
    raise SystemExit("No matching show_map_vma body; NoMount integration stopped")
body, tail = after.split(terminator, 1)
if "vfs_map_meta_override(" in body:
    raise SystemExit("NoMount hook already present; refusing duplicate insertion")
# The last closing brace preceding the normal start/end assignment is 'if (file)'.
marker = "\n\t}\n"
idx = body.rfind(marker)
if idx < 0 or "ino = inode->i_ino;" not in body or "pgoff = " not in body:
    raise SystemExit("Unexpected map file inode layout; NoMount integration stopped")
extra = """
#ifdef CONFIG_NOMOUNT
		{
			extern void vfs_map_meta_override(const struct inode *,
						  dev_t *, unsigned long *);
			vfs_map_meta_override(inode, &dev, &ino);
		}
#endif
"""
body = body[:idx] + "\n" + extra.rstrip("\n") + body[idx:]
path.write_text(before + anchor + body + terminator + tail)
print("NoMount map metadata override inserted after SUSFS processing.")
