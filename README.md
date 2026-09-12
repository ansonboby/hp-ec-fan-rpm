# hp-ec-fan-rpm

Publish the **real fan RPM** of HP 250 G9 laptops (and other Insyde-EC HP
machines with the same register map) to `/run/hp-fan-rpm`, because the
firmware zeroes the WMI fan-speed query — `hp-wmi`'s `fan*_input` in
`/sys/class/hwmon` permanently reads **0 RPM** no matter how fast the fan
spins ([kernel bug 221149](https://bugzilla.kernel.org/show_bug.cgi?id=221149)).

If your fan RPM shows `idle`/`0` while the fan is clearly audible, this is
why. The value is in the embedded controller (EC); you just have to ask the
EC instead of the broken WMI interface.

## How it works

HP's Insyde EC exposes the fan tachometer at EC RAM register `0x11` as
`RPM ÷ 100` (matches the community register map for the HP 250 G8, same EC
firmware family). The kernel's `ec_sys` module (loaded **without**
`write_support`) maps EC RAM read-only to
`/sys/kernel/debug/ec/ec0/io`. This tiny publisher:

1. reads byte `0x11` (offset 17 decimal) every 2 seconds,
2. multiplies by 100 to get RPM,
3. atomically writes it to `/run/hp-fan-rpm` (mode 0644).

A root **systemd service** runs the publisher; the output file is world
readable, so desktop widgets (e.g.
[omarchy-activity-monitor](https://github.com/modib/omarchy-activity-monitor)
with `fanOverridePath = /run/hp-fan-rpm`, htop, waybar scripts) read it
unprivileged.

**No EC writes ever happen.** `ec_sys` is deliberately loaded read-only;
writing EC registers from userspace can brick thermal management (there are
reports of forced-shutdown thermal events on this hardware family), so this
project never does it.

## Install

```sh
git clone https://github.com/ansonboby/hp-ec-fan-rpm.git
cd hp-ec-fan-rpm
sudo ./install.sh
```

`install.sh` loads `ec_sys`, adds it to `/etc/modules-load.d/` (so it
survives reboots), installs the script and unit, and enables the service.

Verify:

```sh
cat /run/hp-fan-rpm   # e.g. 2300 (0 = fan currently off — normal at idle)
systemctl status hp-ec-fan-rpm
```

## Uninstall

```sh
sudo systemctl disable --now hp-ec-fan-rpm
sudo rm /usr/local/bin/hp-ec-fan-rpm /etc/systemd/system/hp-ec-fan-rpm.service /etc/modules-load.d/hp-ec-fan.conf
```

## Files

| File | Purpose |
|---|---|
| `hp-ec-fan-rpm` | The publisher loop (bash + `dd` from `/sys/kernel/debug/ec/ec0/io`) |
| `hp-ec-fan-rpm.service` | systemd unit (`Restart=always`, `ExecStartPre=/sbin/modprobe ec_sys`) |
| `install.sh` | One-shot installer (loads `ec_sys`, installs, enables) |

## Register notes (HP 250 G9, Insyde EC)

| EC offset | Meaning |
|---|---|
| `0x11` | Fan RPM ÷ 100 (0 when the fan is off) |
| `0x15` | Fan mode (0 = auto) — **write-only, never touched here** |
| `0x19` | Fan duty (0–50) — **write-only, never touched here** |

Verified by differential probing: `EC[0x11]` is the only register that moves
0 → 21–35 stepwise while package temp climbs 44→58 °C under 12-thread load
(2100–3500 RPM × the ÷100 scale).

## License

MIT
