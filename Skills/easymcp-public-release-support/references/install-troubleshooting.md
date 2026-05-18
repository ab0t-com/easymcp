# Install Troubleshooting

## Installer Dry Run

Ask the user to run:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_DRY_RUN=1 bash
```

This prints the release asset URL, expected version, install dir, and checksum behavior.

## PATH Issue

Default install dir:

```text
~/.local/bin
```

Check:

```bash
ls -l ~/.local/bin/easymcp
echo "$PATH"
~/.local/bin/easymcp --help
```

If `~/.local/bin` is not on PATH, ask the user to add it to their shell profile.

## Release Asset Issue

Expected asset naming:

```text
easymcp_<version>_<os>_<arch>.tar.gz
checksums.txt
```

Common causes:

- release tag exists but asset is missing
- asset name does not match OS/arch
- checksum file missing or stale
- install dir is not writable

## Safe Information to Request

Ask for:

- OS and architecture
- exact command
- installer output
- `easymcp --version` or `easymcp --help`

Do not ask for secret env values.

