#!/usr/bin/env fish

set SOURCE "$HOME/.var/app"
set CONFIG "$HOME/.config/flatpak-data-manager/config.fish"

# Pastikan konfigurasi tersedia
if not test -f "$CONFIG"
    echo "ERROR: Flatpak Data Manager is not configured."
    echo ""
    echo "Run the setup program first."
    echo ""
    exit 1
end

# Load konfigurasi
source "$CONFIG"

# Pastikan destination sudah dikonfigurasi
if not set -q FLATPAK_DATA_DIR
    echo "ERROR: FLATPAK_DATA_DIR is not configured."
    echo ""
    exit 1
end

set DEST "$FLATPAK_DATA_DIR"

# Pastikan source tersedia
if not test -d "$SOURCE"
    echo "ERROR: source directory does not exist:"
    echo "$SOURCE"
    exit 1
end

# Pastikan destination tersedia
mkdir -p "$DEST"

echo ""
echo "========================================"
echo " Flatpak Data Auto-Migration"
echo "========================================"
echo "Source : $SOURCE"
echo "Target : $DEST"
echo ""

for app_dir in $SOURCE/*

    # Abaikan jika bukan folder atau symlink
    if not test -d "$app_dir"
        continue
    end

    set app_id (basename "$app_dir")

    # Lewati symlink
    if test -L "$app_dir"
        echo "SKIP linked: $app_id"
        continue
    end

    # Lewati backup
    if string match -q '*.backup' "$app_id"
        echo "SKIP backup: $app_id"
        continue
    end

    # Pastikan memang aplikasi Flatpak
    if not flatpak info "$app_id" >/dev/null 2>&1
        echo "SKIP not Flatpak: $app_id"
        continue
    end

    # Jangan pindahkan data ketika aplikasi sedang berjalan
    if flatpak ps --columns=application 2>/dev/null | string match -q -- "$app_id"
        echo "SKIP running: $app_id"
        continue
    end

    set target "$DEST/$app_id"

    echo ""
    echo "----------------------------------------"
    echo "Found: $app_id"

    # Jika target sudah ada, jangan overwrite
    if test -e "$target"
        echo "SKIP target already exists:"
        echo "  $target"
        continue
    end

    echo "Moving data..."
    echo "  FROM: $app_dir"
    echo "  TO  : $target"

    mv "$app_dir" "$target"

    if test $status -ne 0
        echo "ERROR: failed to move $app_id"
        continue
    end

    # Buat symlink kembali ke lokasi standar Flatpak
    ln -s "$target" "$app_dir"

    if test $status -ne 0
        echo "ERROR: failed to create symlink"
        echo "Data remains safely at:"
        echo "  $target"
        continue
    end

    echo "OK: $app_id"
end

echo ""
echo "========================================"
echo " Finished"
echo "========================================"
