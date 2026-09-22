# Flatpak Data Manager

Fish-shell utilities for moving Flatpak application data to another drive while keeping the standard Flatpak paths through symlinks.

## Features

- Move ~/.var/app/<APP_ID> to another filesystem.
- Create symlinks back to the standard Flatpak data location.
- Skip linked applications and backup directories.
- Skip non-Flatpak directories.
- Wait for running Flatpak applications before migration.
- Watch ~/.var/app automatically with inotifywait.
- Manually migrate system Flatpak applications to a custom installation.
- Clean unused references from the default Flatpak installation.

## Requirements

- Linux
- Fish shell
- Flatpak
- inotify-tools

## Configuration

Copy config/config.fish.example to ~/.config/flatpak-data-manager/config.fish and edit the destination paths.

## Usage

### Application data
```fish
~/.local/bin/move-flatpak-data.fish --data
```

### Status
```fish
~/.local/bin/move-flatpak-data.fish --status
```

### Core migration
```fish
~/.local/bin/move-flatpak-data.fish --migrate-core
```

### Cleanup
```fish
~/.local/bin/move-flatpak-data.fish --cleanup-core
```

## License

No license specified yet.
