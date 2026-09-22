#!/usr/bin/env fish

# ============================================================
# Flatpak Data Manager
#
# Default / --data:
#   Memindahkan ~/.var/app/<app-id>
#   ke FLATPAK_DATA_DIR/<app-id>
#   lalu membuat symlink.
#
# --migrate-core:
#   Memindahkan aplikasi dari installation default
#   /var/lib/flatpak ke installation custom.
#
# --cleanup-core:
#   Membersihkan refs yang tidak terpakai dari installation
#   default.
#
# --status:
#   Menampilkan status installation dan penggunaan disk.
# ============================================================

set SOURCE "$HOME/.var/app"
set CONFIG "$HOME/.config/flatpak-data-manager/config.fish"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

if not test -f "$CONFIG"
    echo "ERROR: Flatpak Data Manager is not configured."
    echo ""
    echo "Missing:"
    echo "  $CONFIG"
    echo ""
    exit 1
end

source "$CONFIG"

if not set -q FLATPAK_DATA_DIR
    echo "ERROR: FLATPAK_DATA_DIR is not configured."
    exit 1
end

set DEST "$FLATPAK_DATA_DIR"

if not set -q FLATPAK_INSTALLATION
    set FLATPAK_INSTALLATION "datacachyos"
end

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function is_backup_name
    set name "$argv[1]"

    string match -q '*.backup*' "$name"
    or string match -q '*.bak*' "$name"
end

function is_running
    set app_id "$argv[1]"

    flatpak ps --columns=application 2>/dev/null \
        | string match -q -- "$app_id"
end

# ------------------------------------------------------------
# Application data migration
# ------------------------------------------------------------

function migrate_app_data

    echo ""
    echo "========================================"
    echo " Flatpak Application Data"
    echo "========================================"
    echo "Source : $SOURCE"
    echo "Target : $DEST"
    echo ""

    if not test -d "$SOURCE"
        echo "ERROR: source directory does not exist:"
        echo "  $SOURCE"
        return 1
    end

    mkdir -p "$DEST"

    for app_dir in "$SOURCE"/*

        if not test -e "$app_dir"; and not test -L "$app_dir"
            continue
        end

        set app_id (basename "$app_dir")

        # Already migrated
        if test -L "$app_dir"
            echo "SKIP linked: $app_id"
            continue
        end

        # Backup directories
        if is_backup_name "$app_id"
            echo "SKIP backup: $app_id"
            continue
        end

        # Only directories
        if not test -d "$app_dir"
            echo "SKIP non-directory: $app_id"
            continue
        end

        # Must be a Flatpak application
        if not flatpak info "$app_id" >/dev/null 2>&1
            echo "SKIP not Flatpak: $app_id"
            continue
        end

        # Don't move data of a running app
        if is_running "$app_id"
            echo "SKIP running: $app_id"
            continue
        end

        set target "$DEST/$app_id"

        echo ""
        echo "----------------------------------------"
        echo "Found: $app_id"

        # Don't overwrite existing target
        if test -e "$target"
            echo "SKIP target already exists:"
            echo "  $target"
            continue
        end

        echo "Moving:"
        echo "  FROM: $app_dir"
        echo "  TO  : $target"

        mv "$app_dir" "$target"

        if test $status -ne 0
            echo "ERROR: failed to move $app_id"
            continue
        end

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
    echo " Application data migration finished"
    echo "========================================"
end

# ------------------------------------------------------------
# Core migration
# ------------------------------------------------------------

function migrate_core

    echo ""
    echo "========================================"
    echo " Flatpak Core Migration"
    echo "========================================"
    echo "From : system (/var/lib/flatpak)"
    echo "To   : $FLATPAK_INSTALLATION"
    echo ""

    # Check target installation
    if not flatpak --installation="$FLATPAK_INSTALLATION" list >/dev/null 2>&1
        echo "ERROR: Flatpak installation not available:"
        echo "  $FLATPAK_INSTALLATION"
        echo ""
        echo "Available installations:"
        flatpak --installations
        return 1
    end

    # Get apps from default system installation
    set apps (flatpak --system list --app --columns=application 2>/dev/null)

    if test (count $apps) -eq 0
        echo "No applications are installed in /var/lib/flatpak."
        echo ""
        return 0
    end

    for app_id in $apps

        echo ""
        echo "----------------------------------------"
        echo "Application: $app_id"

        # If already on target, just remove old default copy
        if flatpak --installation="$FLATPAK_INSTALLATION" info "$app_id" >/dev/null 2>&1

            echo "Already exists on $FLATPAK_INSTALLATION."
            echo "Removing default copy..."

            flatpak --system uninstall --app -y "$app_id"

            if test $status -eq 0
                echo "OK: old default copy removed."
            else
                echo "WARNING: could not remove old default copy."
            end

            continue
        end

        # Find origin
        set origin_line (
            flatpak --system info --show-origin "$app_id" 2>/dev/null \
            | string match -r '^Origin:\s*.+$'
        )

        set origin ""

        if test (count $origin_line) -gt 0
            set origin (
                string replace -r '^Origin:\s*' '' "$origin_line[1]"
            )
        end

        if test -z "$origin"
            echo "ERROR: could not determine origin for $app_id"
            echo "Default copy will remain untouched."
            continue
        end

        echo "Origin: $origin"
        echo "Installing into $FLATPAK_INSTALLATION..."

        flatpak --installation="$FLATPAK_INSTALLATION" \
            install -y "$origin" "$app_id"

        if test $status -ne 0
            echo "ERROR: installation failed."
            echo "Default copy will remain untouched."
            continue
        end

        # Verify target installation
        if not flatpak --installation="$FLATPAK_INSTALLATION" \
            info "$app_id" >/dev/null 2>&1

            echo "ERROR: verification failed."
            echo "Default copy will remain untouched."
            continue
        end

        echo "Verified on $FLATPAK_INSTALLATION."

        # IMPORTANT:
        # We do NOT use --delete-data.
        echo "Removing default copy..."

        flatpak --system uninstall --app -y "$app_id"

        if test $status -ne 0
            echo "WARNING:"
            echo "Application is now on $FLATPAK_INSTALLATION,"
            echo "but the old default copy could not be removed."
            continue
        end

        echo "OK: $app_id migrated."
    end

    echo ""
    echo "Cleaning unused refs from default installation..."

    flatpak --system uninstall --unused -y

    echo ""
    echo "========================================"
    echo " Core migration finished"
    echo "========================================"
end

# ------------------------------------------------------------
# Cleanup default installation
# ------------------------------------------------------------

function cleanup_core

    echo ""
    echo "========================================"
    echo " Flatpak Core Cleanup"
    echo "========================================"
    echo ""

    flatpak --system uninstall --unused
end

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

function show_status

    echo ""
    echo "========================================"
    echo " Flatpak Data Manager Status"
    echo "========================================"
    echo ""

    echo "=== Installations ==="
    flatpak --installations

    echo ""
    echo "=== Default System Applications ==="
    flatpak --system list \
        --app \
        --columns=application,name,version

    echo ""
    echo "=== DataCachyOS Applications ==="
    flatpak --installation="$FLATPAK_INSTALLATION" list \
        --app \
        --columns=application,name,version

    echo ""
    echo "=== Paths ==="
    echo "App data:"
    echo "  $DEST"

    echo ""
    echo "=== Disk Usage ==="

    if test -d /var/lib/flatpak
        sudo du -sh /var/lib/flatpak
    end


    if test -d "$DEST"
        du -sh "$DEST"
    end
end

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

switch "$argv[1]"

    case ""
        migrate_app_data

    case "--data"
        migrate_app_data

    case "--migrate-core"
        migrate_core

    case "--cleanup-core"
        cleanup_core

    case "--status"
        show_status

    case "--help" "-h"

        echo "Flatpak Data Manager"
        echo ""
        echo "Usage:"
        echo ""
        echo "  move-flatpak-data.fish"
        echo "      Migrate application data."
        echo ""
        echo "  move-flatpak-data.fish --data"
        echo "      Migrate application data."
        echo ""
        echo "  move-flatpak-data.fish --migrate-core"
        echo "      Migrate system Flatpak applications"
        echo "      from /var/lib/flatpak to $FLATPAK_INSTALLATION."
        echo ""
        echo "  move-flatpak-data.fish --cleanup-core"
        echo "      Remove unused refs from the default"
        echo "      system installation."
        echo ""
        echo "  move-flatpak-data.fish --status"
        echo "      Show Flatpak installation status."

    case "*"

        echo "ERROR: unknown option: $argv[1]"
        echo ""
        echo "Use --help for help."
        exit 1

end
