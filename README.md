text

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
- `inotify-tools` (for the watcher)

## Installation

No installer is provided. Copy the scripts manually and make them executable:

```fish
mkdir -p ~/.local/bin
cp scripts/move-flatpak-data.fish ~/.local/bin/
cp scripts/flatpak-data-watcher.fish ~/.local/bin/
chmod +x ~/.local/bin/*.fish

Ensure ~/.local/bin is in your $PATH.
Configuration

Copy the example config and edit the destination paths:
fish

mkdir -p ~/.config/flatpak-data-manager
cp config/config.fish.example ~/.config/flatpak-data-manager/config.fish
$EDITOR ~/.config/flatpak-data-manager/config.fish

Available options:
Variable	Default	Description
FLATPAK_DATA_DIR	$HOME/Flatpak Data	Directory where Flatpak application user data is stored.
FLATPAK_INSTALLATION	datacachyos	Name of the custom Flatpak installation. Change only if your installation uses another name.
Usage
Migrate application data
fish

move-flatpak-data.fish --data

Moves each Flatpak app directory in ~/.var/app to $FLATPAK_DATA_DIR
and replaces it with a symlink.
Show status
fish

move-flatpak-data.fish --status

Prints the current Flatpak installation status.
Migrate system Flatpak applications
fish

move-flatpak-data.fish --migrate-core

Migrates system Flatpak applications from /var/lib/flatpak to the custom
installation named by $FLATPAK_INSTALLATION.
Clean up unused references
fish

move-flatpak-data.fish --cleanup-core

Removes unused refs from the default system installation.
Watch for new Flatpak data
fish

flatpak-data-watcher.fish

Runs a one-time migration, then watches ~/.var/app with inotifywait
and migrates new app data as it appears. This command blocks the terminal;
run it in the background, a separate terminal, or as a systemd user service.
License

MIT License — see LICENSE.
