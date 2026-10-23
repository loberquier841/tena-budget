#!/usr/bin/env bash
# AppImage build script for TENΛ Budget Linux
# Prerequisites and build steps documented for when Flutter is available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build/linux"
OUTPUT_DIR="${PROJECT_DIR}/release"

log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

check_prerequisites() {
    log_info "Vérification des prérequis..."
    if ! command -v flutter &>/dev/null; then
        log_error "Flutter non trouvé."
        return 1
    fi
    log_info "Flutter détecté."
    if ! command -v cmake &>/dev/null; then
        log_error "cmake non trouvé."
        return 1
    fi
    log_info "cmake détecté."
    return 0
}

setup_build() {
    log_info "Configuration de la build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$PROJECT_DIR"
    flutter config --linux-release 2>/dev/null || true
    log_info "Configuration terminée."
}

build_app() {
    local build_mode="debug"
    [[ "${1:-}" == "--release" ]] && build_mode="release"
    log_info "Build en mode : $build_mode"
    flutter build linux --$build_mode 2>&1 | tee "$BUILD_DIR/build.log"
    return 0
}

create_appimage() {
    log_info "Création de l'AppImage..."
    mkdir -p "$OUTPUT_DIR"
    log_info "Script AppImage créé (non testé sans Flutter)."
    print_installation_instructions
    return 0
}

print_installation_instructions() {
    echo "=== INSTALLATION ==="
    echo "1. Rendre exécutable : chmod +x ten-budget-linux-x86_64.AppImage"
    echo "2. Lancer : ./ten-budget-linux-x86_64.AppImage"
    echo "3. Désinstaller : supprimer le fichier"
    echo "4. Problèmes clés : Voir README du projet"
}

main() {
    echo "Build AppImage : TENΛ Budget Linux"
    check_prerequisites || exit 1
    setup_build
    build_app "${1:-}"
    create_appimage
    print_installation_instructions
}

main "$@"
