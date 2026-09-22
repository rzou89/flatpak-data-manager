#!/usr/bin/env fish

set APP_NAME "Flatpak Data Manager"
set CONFIG_DIR "$HOME/.config/flatpak-data-manager"
set CONFIG_FILE "$CONFIG_DIR/config.fish"
set INSTALL_DIR "$HOME/.local/bin"
set SERVICE_DIR "$HOME/.config/systemd/user"

echo ""
echo "========================================"
echo " $APP_NAME - Setup"
echo "========================================"
echo ""

# ----------------------------------------
# Check Fish
# ----------------------------------------

if not type -q fish
    echo "ERROR: Fish shell is not installed."
    exit 1
end

echo "OK: Fish"

# ----------------------------------------
# Check Flatpak
# ----------------------------------------

if not type -q flatpak
    echo "ERROR: Flatpak is not installed."
    exit 1
end

echo "OK: Flatpak"

# ----------------------------------------
# Check inotifywait
# ----------------------------------------

if not type -q inotifywait
    echo "ERROR: inotifywait is not installed."
    echo ""
    echo "Please install the 'inotify-tools' package using your distribution's"
    echo "package manager, then run this installer again."
    echo ""
    echo "Examples:"
    echo "  Arch/CachyOS: sudo pacman -S inotify-tools"
    echo "  Debian/Ubuntu: sudo apt install inotify-tools"
    echo "  Fedora: sudo dnf install inotify-tools"
    echo ""
    exit 1
end

echo "OK: inotifywait"

# ----------------------------------------
# Check systemctl
# ----------------------------------------

if not type -q systemctl
    echo "ERROR: systemctl is not available."
    exit 1
end

echo "OK: systemctl"

echo ""
echo "All required dependencies are available."
echo ""

# ----------------------------------------
# Choose Flatpak data directory
# ----------------------------------------

echo "Where should Flatpak application data be stored?"
echo ""
echo "Example:"
echo "  /mnt/MySSD/Flatpak Data"
echo ""

if test -f "$CONFIG_FILE"
    source "$CONFIG_FILE"

    if set -q FLATPAK_DATA_DIR
        echo "Current destination:"
        echo "  $FLATPAK_DATA_DIR"
        echo ""
        read -P "Use this destination? [Y/n]: " use_current

        if test -z "$use_current"; or string match -qi "y" "$use_current"
            set DEST "$FLATPAK_DATA_DIR"
        end
    end
end

if not set -q DEST
    read -P "Enter destination folder: " DEST
end

# Remove trailing slash
set DEST (string trim -r -c / -- "$DEST")

# Destination must be absolute
if not string match -q '/*' "$DEST"
    echo ""
    echo "ERROR: destination must be an absolute path."
    echo "Example: /mnt/MySSD/Flatpak Data"
    exit 1
end

# Do not allow destination inside ~/.var/app
set APP_DATA_ROOT "$HOME/.var/app"

if test "$DEST" = "$APP_DATA_ROOT"
    echo ""
    echo "ERROR: destination cannot be ~/.var/app."
    exit 1
end

if string match -q "$APP_DATA_ROOT/*" "$DEST"
    echo ""
    echo "ERROR: destination cannot be inside ~/.var/app."
    exit 1
end

echo ""
echo "Selected destination:"
echo "  $DEST"
echo ""

read -P "Is this correct? [Y/n]: " confirm

if test -n "$confirm"; and not string match -qi "y" "$confirm"
    echo ""
    echo "Setup cancelled."
    exit 0
end

echo ""
echo "Destination confirmed."
echo ""

# ----------------------------------------
# Save configuration
# ----------------------------------------

mkdir -p "$CONFIG_DIR"

if not test -d "$CONFIG_DIR"
    echo "ERROR: failed to create configuration directory:"
    echo "  $CONFIG_DIR"
    exit 1
end

echo "Saving configuration..."

printf 'set -gx FLATPAK_DATA_DIR %s\n' (string escape -- "$DEST") > "$CONFIG_FILE"

if test $status -ne 0
    echo ""
    echo "ERROR: failed to save configuration:"
    echo "  $CONFIG_FILE"
    exit 1
end

echo "OK: configuration saved."
echo ""

# ----------------------------------------
# Install scripts
# ----------------------------------------

echo "Installing scripts..."

mkdir -p "$INSTALL_DIR"

if test $status -ne 0
    echo "ERROR: failed to create install directory:"
    echo "  $INSTALL_DIR"
    exit 1
end

set PROJECT_DIR (dirname (status --current-filename))

cp "$PROJECT_DIR/scripts/move-flatpak-data.fish" \
   "$INSTALL_DIR/move-flatpak-data.fish"

if test $status -ne 0
    echo "ERROR: failed to install migration script."
    exit 1
end

cp "$PROJECT_DIR/scripts/flatpak-data-watcher.fish" \
   "$INSTALL_DIR/flatpak-data-watcher.fish"

if test $status -ne 0
    echo "ERROR: failed to install watcher script."
    exit 1
end

chmod +x \
    "$INSTALL_DIR/move-flatpak-data.fish" \
    "$INSTALL_DIR/flatpak-data-watcher.fish"

echo "OK: scripts installed."
echo ""

# ----------------------------------------
# Install systemd user service
# ----------------------------------------

echo "Installing systemd user service..."

mkdir -p "$SERVICE_DIR"

if test $status -ne 0
    echo "ERROR: failed to create systemd user directory:"
    echo "  $SERVICE_DIR"
    exit 1
end

set PROJECT_DIR (dirname (status --current-filename))
set SERVICE_SOURCE "$PROJECT_DIR/systemd/flatpak-data-watcher.service"
set SERVICE_TARGET "$SERVICE_DIR/flatpak-data-watcher.service"

cp "$SERVICE_SOURCE" "$SERVICE_TARGET"

if test $status -ne 0
    echo "ERROR: failed to install systemd service."
    exit 1
end

systemd-analyze --user verify "$SERVICE_TARGET"

if test $status -ne 0
    echo "ERROR: installed systemd service is invalid."
    exit 1
end

systemctl --user daemon-reload

if test $status -ne 0
    echo "ERROR: systemd daemon-reload failed."
    exit 1
end

systemctl --user enable flatpak-data-watcher.service

if test $status -ne 0
    echo "ERROR: failed to enable systemd service."
    exit 1
end

echo "OK: systemd service installed and enabled."
echo ""

# ----------------------------------------
# Initial migration
# ----------------------------------------

echo "Running initial Flatpak data migration..."
echo ""

"$INSTALL_DIR/move-flatpak-data.fish"

if test $status -ne 0
    echo ""
    echo "ERROR: initial migration failed."
    echo "The systemd service was installed but has not been started."
    exit 1
end

echo ""
echo "OK: initial migration completed."
echo ""

# ----------------------------------------
# Start watcher
# ----------------------------------------

echo "Starting Flatpak Data Watcher..."

systemctl --user restart flatpak-data-watcher.service

if test $status -ne 0
    echo ""
    echo "ERROR: failed to start systemd service."
    echo ""
    echo "Check the service with:"
    echo "  systemctl --user status flatpak-data-watcher.service"
    exit 1
end

sleep 1

if systemctl --user is-active --quiet flatpak-data-watcher.service
    echo "OK: Flatpak Data Watcher is running."
else
    echo ""
    echo "ERROR: Flatpak Data Watcher did not start correctly."
    echo ""
    echo "Check the service with:"
    echo "  systemctl --user status flatpak-data-watcher.service"
    exit 1
end

echo ""
echo "========================================"
echo " Setup completed successfully!"
echo "========================================"
echo ""
echo "Flatpak data directory:"
echo "  $DEST"
echo ""
echo "Watcher:"
echo "  systemctl --user status flatpak-data-watcher.service"
echo ""
echo "The watcher will start automatically after login."
echo ""
