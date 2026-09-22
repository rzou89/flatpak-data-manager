#!/usr/bin/env fish

set APP_NAME "Flatpak Data Manager"
set INSTALL_DIR "$HOME/.local/bin"
set SERVICE_DIR "$HOME/.config/systemd/user"
set CONFIG_DIR "$HOME/.config/flatpak-data-manager"
set SERVICE "$SERVICE_DIR/flatpak-data-watcher.service"

echo ""
echo "========================================"
echo " $APP_NAME - Uninstall"
echo "========================================"
echo ""

read -P "Remove Flatpak Data Manager? [y/N]: " confirm

if not string match -qi "y" "$confirm"
    echo "Uninstall cancelled."
    exit 0
end

echo ""
echo "Stopping watcher..."

systemctl --user disable --now flatpak-data-watcher.service 2>/dev/null

rm -f "$SERVICE"
rm -f "$INSTALL_DIR/move-flatpak-data.fish"
rm -f "$INSTALL_DIR/flatpak-data-watcher.fish"

systemctl --user daemon-reload

read -P "Remove configuration at $CONFIG_DIR? [y/N]: " remove_config

if string match -qi "y" "$remove_config"
    rm -rf "$CONFIG_DIR"
    echo "Configuration removed."
else
    echo "Configuration kept at: $CONFIG_DIR"
end

echo ""
echo "Flatpak Data Manager has been removed."
echo ""
echo "Your Flatpak application data was NOT deleted."
echo "Your Flatpak applications were NOT deleted."
echo ""
