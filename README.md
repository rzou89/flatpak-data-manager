# Flatpak Data Manager

Flatpak Data Manager automatically moves Flatpak application data from `~/.var/app` to a separate storage location and creates symbolic links back to the standard Flatpak path.

The goal is to keep large Flatpak application data away from the system drive while preserving the normal Flatpak directory structure.

## Features

* Automatically migrates Flatpak application data to a configurable destination.
* Uses symbolic links so Flatpak continues to access the standard path.
* Automatically detects newly created Flatpak application data.
* Runs as a user-level `systemd` service.
* Uses `inotifywait` for event-driven monitoring instead of continuous polling.
* Skips applications that are already linked.
* Skips backup directories.
* Skips directories that are not Flatpak applications.
* Does not overwrite an existing destination directory.
* Safe to run repeatedly because migration is idempotent.
* Configuration is stored outside the Git repository.

## How It Works

Normally Flatpak application data is stored under:

```text
~/.var/app/
```

For example:

```text
~/.var/app/com.tencent.WeChat/
```

After migration, the actual data can be stored on another drive:

```text
/mnt/DataCachyOS/Flatpak Data/com.tencent.WeChat/
```

and the original path becomes a symbolic link:

```text
~/.var/app/com.tencent.WeChat
    -> /mnt/DataCachyOS/Flatpak Data/com.tencent.WeChat
```

Flatpak continues to use the standard path, while the actual data is stored on the selected drive.

## Requirements

The system must have:

* Fish shell
* Flatpak
* `inotifywait` from `inotify-tools`
* `systemctl` with user services enabled

On CachyOS / Arch Linux, `inotify-tools` can be installed with:

```fish
sudo pacman -S inotify-tools
```

## Installation

Clone the repository:

```fish
git clone <REPOSITORY_URL>
cd flatpak-data-manager
```

Run the setup program:

```fish
./setup.fish
```

The installer will:

1. Check required dependencies.
2. Ask where Flatpak data should be stored.
3. Save the destination in:

```text
~/.config/flatpak-data-manager/config.fish
```

4. Install the migration and watcher scripts into:

```text
~/.local/bin/
```

5. Install the user-level systemd service into:

```text
~/.config/systemd/user/
```

6. Perform an initial migration.
7. Enable and start the watcher service.

## Configuration

The destination directory is stored outside the repository:

```text
~/.config/flatpak-data-manager/config.fish
```

Example:

```fish
set -gx FLATPAK_DATA_DIR '/mnt/DataCachyOS/Flatpak Data'
```

This keeps machine-specific paths out of Git.

## Service Management

Check the watcher:

```fish
systemctl --user status flatpak-data-watcher.service
```

Restart the watcher:

```fish
systemctl --user restart flatpak-data-watcher.service
```

Stop the watcher:

```fish
systemctl --user stop flatpak-data-watcher.service
```

Start the watcher:

```fish
systemctl --user start flatpak-data-watcher.service
```

The service is enabled to start automatically after the user session starts.

## Manual Migration

The migration script can also be run manually:

```fish
~/.local/bin/move-flatpak-data.fish
```

The script checks each directory under:

```text
~/.var/app
```

and only migrates valid Flatpak application data that has not already been migrated.

## Safety Behavior

The migration process is designed to avoid destructive overwrites.

It will skip:

* Existing symbolic links.
* Backup directories such as `*.backup`.
* Directories that are not recognized as Flatpak applications.
* Applications that are currently running.
* Destination directories that already exist.

Existing destination data is never automatically overwritten.

## Project Structure

```text
flatpak-data-manager/
├── flatpak_data_manager/
│   ├── __init__.py
│   ├── __main__.py
│   └── cli.py
├── scripts/
│   ├── move-flatpak-data.fish
│   └── flatpak-data-watcher.fish
├── systemd/
│   └── flatpak-data-watcher.service
├── tests/
├── setup.fish
├── pyproject.toml
├── requirements.txt
├── README.md
└── .gitignore
```

## Architecture

The project consists of three main components:

### Migration Script

```text
scripts/move-flatpak-data.fish
```

Responsible for detecting Flatpak application data and moving it to the configured destination.

### Watcher

```text
scripts/flatpak-data-watcher.fish
```

Uses `inotifywait` to detect new directories under:

```text
~/.var/app
```

When new Flatpak data appears, the migration process is triggered automatically.

### systemd User Service

```text
systemd/flatpak-data-watcher.service
```

Keeps the watcher running in the user's session and automatically starts it after login.

## Project Goal

This project is designed as a simple, portable solution for users who want to keep Flatpak application data on a separate drive without manually managing symbolic links for every application.

The configuration is intentionally kept outside the repository so the same project can be backed up to GitHub and installed on another Linux system with a different storage layout.

## License

License information has not yet been defined.
