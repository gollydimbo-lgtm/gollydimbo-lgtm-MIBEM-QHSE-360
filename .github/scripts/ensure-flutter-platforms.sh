#!/usr/bin/env bash
# Génère le socle natif Android + Windows du client Flutter s'il n'existe pas
# déjà (le dépôt source ne contient que lib/ et pubspec.yaml : les dossiers
# natifs doivent être produits par le vrai SDK Flutter, pas écrits à la main).
# Idempotent : ne touche pas lib/, pubspec.yaml, ni un dossier déjà généré.
set -euo pipefail
cd "$(dirname "$0")/../../apps/flutter"

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

# file_picker (via flutter_plugin_android_lifecycle) exige compileSdk >= 36 ;
# le squelette généré par "flutter create" pointe encore vers 34 par défaut.
# IMPORTANT : en Kotlin DSL comme en Groovy, c'est la DERNIÈRE affectation
# d'une propriété dans le fichier qui l'emporte. On insère donc notre
# "compileSdk = 36" juste APRÈS la ligne d'origine (pas après l'ouverture du
# bloc "android {", qui se trouve avant et serait donc écrasée par elle).
patch_compile_sdk() {
  local file="$1" pattern="$2" line="$3"
  [ -f "$file" ] || return 0
  grep -qE "$pattern" "$file" || return 0
  local last_line
  last_line=$(grep -E "compileSdk" "$file" | tail -n 1)
  case "$last_line" in
    *"$line"*) return 0 ;; # déjà patché, la dernière ligne est déjà la nôtre
  esac
  sed -i -E "0,/$pattern/{s/($pattern)/\1\n    ${line}/}" "$file"
  echo "== $line injecté après la ligne compileSdk d'origine dans $file =="
}
patch_compile_sdk "android/app/build.gradle.kts" "compileSdk[[:space:]]*=[[:space:]]*(flutter\.compileSdkVersion|[0-9]+)" "compileSdk = 36"
patch_compile_sdk "android/app/build.gradle" "compileSdkVersion[[:space:]]+(flutter\.compileSdkVersion|[0-9]+)" "compileSdkVersion 36"

for GRADLE_FILE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE_FILE" ]; then
    echo "== Contenu compileSdk final dans $GRADLE_FILE (la DERNIÈRE ligne fait foi) =="
    grep -n "compileSdk" "$GRADLE_FILE" || echo "  (aucune ligne compileSdk trouvée)"
  fi
done

CMAKE="windows/runner/CMakeLists.txt"
if [ -f "$CMAKE" ]; then
  sed -i 's/set(BINARY_NAME "qhse_mobile")/set(BINARY_NAME "QHSE_MIBEM")/' "$CMAKE" || true
fi

echo "== Socle Flutter prêt =="
