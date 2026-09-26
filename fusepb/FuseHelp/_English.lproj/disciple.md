---
title: DISCiPLE Emulation
description: This section describes the DISCiPLE interface emulation in Fuse.
order: 120
group: Floppy Disk Interfaces
---

Fuse supports emulating the DISCiPLE disk and printer interface, although it
does not currently support the Sinclair Network. The DISCiPLE works with 48K,
128K and grey +2 machines, but not +2A or +3 machines. See the
[Disk File Formats](formats.html) section for supported disk formats, which
are the same as for +D emulation. The DISCiPLE's printer port is emulated (see
[Printer Emulation](printer.html)). To access disks, load GDOS by inserting a
disk containing the DOS file (SYS) and entering "RUN". Once DOS is loaded, you
can load to/from DISCiPLE disks by prefixing filenames with 'd n' where ' n '
is the number of the drive in use.  For example, `LOAD d1;"myfile"` would load
the file named 'myfile' from the emulated drive 1. Microdrive syntax may also
be used.

The *DISCiPLE inhibit* switch in [Peripherals preferences](peripherals.html)
controls whether the interface pages into memory. Turning it on immediately
pages the DISCiPLE out. With the switch off, automatic paging is enabled;
with it on, control-port bit 4 can still permit subsequent paging triggers.

Snapshots can be saved in a similar manner to that of the +D as described above,
but note that GDOS on the DISCiPLE contains a bug which causes corruption as
soon as the NMI button is pressed, affecting saving of snapshots, and also
loading of snapshots that were originally saved with a +D or SAM Coupé. This
will cause corruption even when a screenshot is printed, or if the menu is never
even entered in the first place (due to Caps Shift not being pressed down, as is
required for the DISCiPLE), provided that GDOS is loaded. This bug is not
present in G+DOS on the +D. (Note: this was caused by saving/restoring the AF
register twice in the NMI handler, where both AF and the AF' shadow register
should have been saved/restored.)

The NMI button works slightly differently on the DISCiPLE than on the +D. Caps
Shift must be held down whilst pressing the NMI button, and there is no ‘X’
option to exit the menu. Also, printing of screenshots requires GDOS to be
loaded.
