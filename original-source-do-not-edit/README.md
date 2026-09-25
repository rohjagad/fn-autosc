# Original source — reference only, **do not edit**

These are the unmodified reference archives kept for comparison when auditing
`fn-autosc`. Nothing here is built, installed or shipped — the installer never
reads this directory.

| Archive | What it is |
| :--- | :--- |
| `Autoscript New 1.20.zip` | The 1.20 autoscript. It is the last version that served the WebSocket transport with **Xray** (no `v2ray.sh`), so it defined the target layout for the V2Ray → Xray migration — see `project-information/is-decision.md` section 13. |
| `V23 Linux Ubuntu, Debian, Kali.zip` | The V23 archive the fork was published from. Used as the behavioural baseline in the regression and false-positive audits — see `project-information/bug-fixes-regression.md` and `bugs-fixed.md`. |

## Rules

- **Do not edit, reformat, re-zip or "clean up" anything in here.** The audits
  compare against these exact bytes; a modified copy invalidates them.
- Do not reference this directory from installers, menus or build scripts.
- Add a new archive alongside these rather than replacing one, and record it in
  the table above with its checksums.

## Integrity

Recorded so a changed copy is detectable:

| Archive | Size (bytes) | MD5 | SHA-256 |
| :--- | ---: | :--- | :--- |
| `Autoscript New 1.20.zip` | 10467901 | `fdc1097ec7e10047a6d5af4c0e1cf6d5` | `9b3e4fbeadb05d78becfe0ed11741ab7fed482ebbf6e17c290bcf2c1ce82958a` |
| `V23 Linux Ubuntu, Debian, Kali.zip` | 26383767 | `a3d06894546eb982e4ab474cddbbb3c0` | `58f5bca995e512001ee0739b2844862220807f92a9c25d20ca16b5e1b35a5b4a` |
