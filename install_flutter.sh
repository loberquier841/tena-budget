#!/usr/bin/env bash
# Script d'installation automatique du SDK Flutter pour macOS (Apple Silicon arm64 & Intel)
# 100% gratuit et open-source

set -e

echo "========================================================="
echo "  INSTALLATION DU SDK FLUTTER POUR TENΛ BUDGET (macOS)"
echo "========================================================="

FLUTTER_DIR="$HOME/flutter"

if [ -d "$FLUTTER_DIR" ]; then
    echo "Le dossier $FLUTTER_DIR existe déjà."
else
    echo "Clonage de la branche stable officielle de Flutter dans $FLUTTER_DIR..."
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
fi

echo "Configuration du PATH dans ~/.zprofile..."
if ! grep -q "flutter/bin" ~/.zprofile 2>/dev/null; then
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zprofile
    echo "PATH ajouté à ~/.zprofile."
else
    echo "PATH déjà configuré dans ~/.zprofile."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Vérification de Flutter..."
flutter --version

echo "Compilation des dépendances de tena_app..."
cd "$(dirname "$0")/tena_app"
flutter pub get

echo "========================================================="
echo "  ✓ FLUTTER EST PRÊT SUR VOTRE MAC !"
echo "  Pour lancer l'application Flutter native sur votre Mac :"
echo "    cd ~/tena-budget/tena_app && flutter run -d macos"
echo "  Pour compiler l'APK Android :"
echo "    cd ~/tena-budget/tena_app && flutter build apk --release"
echo "========================================================="
