# Menu payload manifests

`full.manifest` and `lite.manifest` list every command the installer puts in
`/usr/bin`. Each line is one of:

```text
script  <name>     # installed from <edition>/<name>.sh
bin     <name>     # installed from bin/<edition>/<name>
```

The old `full.zip` / `lite.zip` archives were removed in Fix 513. The installer
downloads the manifest and each file individually; `installer/payload.sh`
stages and verifies everything before replacing anything in `/usr/bin`.

## Changing a shell command

Edit `full/<name>.sh` or `lite/<name>.sh` and commit it. No repack.

## Changing a compiled command

Edit the matching `.go` source, run:

```bash
tools/build-binaries.sh
```

commit the changed `bin/<edition>/<name>`, then run:

```bash
tools/verify-payload.sh
```

## Adding or removing a command

Add/remove its line in the manifest and the matching source or binary. Run
`tools/verify-payload.sh` before committing.
