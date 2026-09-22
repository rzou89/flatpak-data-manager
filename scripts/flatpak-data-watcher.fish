#!/usr/bin/env fish

set SOURCE "$HOME/.var/app"
set CORE_SOURCE "/var/lib/flatpak"
set CONFIG "$HOME/.config/flatpak-data-manager/config.fish"
set MIGRATOR "$HOME/.local/bin/move-flatpak-data.fish"

echo ""
echo "========================================"
echo " Flatpak Data Watcher"
echo "========================================"
echo "Watching: $SOURCE"
echo "========================================"
echo ""

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

# Pastikan destination dikonfigurasi
if not set -q FLATPAK_DATA_DIR
    echo "ERROR: FLATPAK_DATA_DIR is not configured."
    echo ""
    exit 1
end

# Pastikan source tersedia
if not test -d "$SOURCE"
    echo "ERROR: source directory does not exist:"
    echo "$SOURCE"
    exit 1
end

# Pastikan Flatpak core source tersedia
if not test -d "$CORE_SOURCE"
    echo "ERROR: Flatpak core directory does not exist:"
    echo "$CORE_SOURCE"
    exit 1
end

# Pastikan migration script tersedia
if not test -x "$MIGRATOR"
    echo "ERROR: migration script is missing or not executable:"
    echo "$MIGRATOR"
    exit 1
end

# Proses folder yang sudah ada terlebih dahulu.
# Aman karena migration script bersifat idempotent.
"$MIGRATOR"

echo ""
echo "Watcher is now waiting for new Flatpak data..."
echo ""

function wait_for_core_changes
    echo "  Waiting for Flatpak installation to finish..."

    while true
        set before (find "$CORE_SOURCE" -type f -printf "%T@
" 2>/dev/null | sort -nr | head -1)
        sleep 2
        set after (find "$CORE_SOURCE" -type f -printf "%T@
" 2>/dev/null | sort -nr | head -1)

        if test "$before" = "$after"
            break
        end
    end

    echo "  Flatpak core changes finished."
end

while true

    # Menunggu folder baru langsung di ~/.var/app/
    set event (inotifywait \
        -r \
        -q \
        -e create \
        -e moved_to \
        --format '%w|%f' \
        "$SOURCE" "$CORE_SOURCE")

    if test $status -ne 0
        sleep 1
        continue
    end

    set event_parts (string split '|' "$event")
    set event_source "$event_parts[1]"
    set event_name "$event_parts[2]"

    # Perubahan pada core Flatpak
    if string match -q "$CORE_SOURCE/*" "$event_source"
        echo ""
        echo "Watcher detected Flatpak core change:"
        echo "  $event_name"

        wait_for_core_changes

        echo "  Running core migration..."
        "$MIGRATOR" --migrate-core

        echo ""
        echo "Watcher: waiting..."
        continue
    end


    # Perubahan pada app-data
    if test "$event_source" = "$SOURCE/"
        set app_id "$event_name"
        set app_dir "$SOURCE/$app_id"
    else
        continue
    end

    # Hanya proses directory
    if not test -d "$app_dir"
        continue
    end

    # Symlink tidak perlu diproses
    if test -L "$app_dir"
        continue
    end

    # Backup tidak perlu diproses
    if string match -q '*.backup*' "$app_id"
        echo "Watcher: SKIP backup: $app_id"
        continue
    end

    # Pastikan ini aplikasi Flatpak
    if not flatpak info "$app_id" >/dev/null 2>&1
        echo "Watcher: SKIP not Flatpak: $app_id"
        continue
    end

    echo ""
    echo "Watcher detected:"
    echo "  $app_id"

    # Jika aplikasi sedang berjalan, tunggu sampai benar-benar tutup.
    while true
        set running_apps (flatpak ps --columns=application 2>/dev/null)

        if not contains -- "$app_id" $running_apps
            break
        end

        echo "  $app_id is running. Waiting for application to close..."
        sleep 2
    end

    echo "  $app_id is closed."
    echo "  Running migration..."

    "$MIGRATOR"

    echo ""
    echo "Watcher: waiting..."
end
