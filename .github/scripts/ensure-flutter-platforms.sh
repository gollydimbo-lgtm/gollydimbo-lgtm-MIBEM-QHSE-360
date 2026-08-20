#!/usr/bin/env bash
# Génère le socle natif Android + Windows du client Flutter s'il n'existe pas
# déjà (le dépôt source ne contient que lib/ et pubspec.yaml : les dossiers
# natifs doivent être produits par le vrai SDK Flutter, pas écrits à la main).
# Idempotent : ne touche pas lib/, pubspec.yaml, ni un dossier déjà généré.
set -euo pipefail
cd "$(dirname "$0")/../apps/flutter"

if [ ! -d "android" ] || [ ! -d "windows" ]; then
  echo "== Génération des dossiers natifs manquants (android/windows) =="
  flutter create --platforms=android,windows --org=com.mibem --project-name=qhse_mobile .
else
  echo "== Dossiers natifs déjà présents, génération ignorée =="
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  echo "== Vérification des permissions Android =="
  for PERM in \
    "android.permission.INTERNET" \
    "android.permission.CAMERA" \
    "android.permission.ACCESS_FINE_LOCATION" \
    "android.permission.ACCESS_COARSE_LOCATION" \
    "android.permission.READ_MEDIA_IMAGES"
  do
    if ! grep -q "\"$PERM\"" "$MANIFEST"; then
      echo "  + ajout de $PERM"
      sed -i "s#<manifest #<manifest #; s#</manifest>#    <uses-permission android:name=\"$PERM\" />\n</manifest>#" "$MANIFEST"
    fi
  done
  # Nom d'application affiché sur l'appareil
  if grep -q 'android:label="qhse_mobile"' "$MANIFEST"; then
    sed -i 's/android:label="qhse_mobile"/android:label="QHSE MIBEM"/' "$MANIFEST"
  fi
fi

CMAKE="windows/runner/CMakeLists.txt"
if [ -f "$CMAKE" ]; then
  sed -i 's/set(BINARY_NAME "qhse_mobile")/set(BINARY_NAME "QHSE_MIBEM")/' "$CMAKE" || true
fi

echo "== Socle Flutter prêt =="
