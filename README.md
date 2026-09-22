# Flatpak Data Manager

Fish-shell utilities for moving Flatpak application data to another drive while
keeping the standard Flatpak paths through symlinks.

## Features

- Move `~/.var/app/<APP_ID>` to another filesystem.
- Create symlinks back to the standard Flatpak data location.
- Watch `~/.var/app` automatically with `inotifywait` and migrate new app data.
- Skip already-linked apps, backup directories, and non-Flatpak directories.
- Wait for running Flatpak applications before migration.
- Migrate system Flatpak applications to a custom installation.
- Clean unused references from the default Flatpak installation.

## Requirements

- Linux
- Fish shell
- Flatpak
- `inotify-tools` (provides `inotifywait`)
- `systemd` (for the optional watcher service)

## Installation

Clone the repository and run the installer:

```fish
git clone git@github.com:rzou89/flatpak-data-manager.git
cd flatpak-data-manager
./setup.fish
```

The installer will:

1. Check that Fish, Flatpak, `inotifywait`, and `systemctl` are available.
2. Ask for the destination folder where Flatpak data should be stored.
3. Write the config to `~/.config/flatpak-data-manager/config.fish`.
4. Copy the scripts to `~/.local/bin`.
5. Install and enable the systemd user service
   `~/.config/systemd/user/flatpak-data-watcher.service`.
6. Run an initial migration of `~/.var/app` to the destination.
7. Migrate system Flatpak applications to the custom installation.
8. Start the watcher service and verify it is running.

### Uninstall

```fish
./uninstall.fish
```

## Configuration

The installer writes `~/.config/flatpak-data-manager/config.fish`. To edit it
manually, copy the example:

```fish
mkdir -p ~/.config/flatpak-data-manager
cp config/config.fish.example ~/.config/flatpak-data-manager/config.fish
$EDITOR ~/.config/flatpak-data-manager/config.fish
```

Available options:

| Variable | Default | Description |
|----------|---------|-------------|
| `FLATPAK_DATA_DIR` | `$HOME/Flatpak Data` | Directory where Flatpak application user data is stored. |
| `FLATPAK_INSTALLATION` | `datacachyos` | Name of the custom Flatpak installation. Change only if your installation uses another name. |

## Usage

### Migrate application data

```fish
move-flatpak-data.fish --data
```

Moves each Flatpak app directory in `~/.var/app` to `$FLATPAK_DATA_DIR`
and replaces it with a symlink.

### Show status

```fish
move-flatpak-data.fish --status
```

Prints the current Flatpak installation status.

### Migrate system Flatpak applications

```fish
move-flatpak-data.fish --migrate-core
```

Migrates system Flatpak applications from `/var/lib/flatpak` to the custom
installation named by `$FLATPAK_INSTALLATION`.

### Clean up unused references

```fish
move-flatpak-data.fish --cleanup-core
```

Removes unused refs from the default system installation.

### Watch for new Flatpak data

```fish
flatpak-data-watcher.fish
```

Runs a one-time migration, then watches `~/.var/app` with `inotifywait`
and migrates new app data as it appears. **This command blocks the terminal**.

### Manage the watcher service

The installer already enables and starts `flatpak-data-watcher.service`.
Check its status or logs with:

```fish
systemctl --user status flatpak-data-watcher.service
journalctl --user -u flatpak-data-watcher.service -f
```

To stop or disable it:

```fish
systemctl --user disable --now flatpak-data-watcher.service
```

## License

MIT License — see [LICENSE](LICENSE).
