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
# Méthode robuste : Gradle (Kotlin DSL comme Groovy) accepte plusieurs blocs
# "android { }" dans un même script, exécutés dans l'ordre du fichier. On
# AJOUTE donc un second bloc à la toute fin, qui s'exécute après le premier
# et l'emporte — sans dépendre du format exact de la ligne d'origine.
add_compile_sdk_override() {
  local file="$1" marker="$2" body="$3"
  [ -f "$file" ] || return 0
  grep -qF "$marker" "$file" && return 0 # déjà appliqué
  {
    echo ""
    echo "$marker"
    echo "android {"
    echo "    $body"
    echo "}"
  } >> "$file"
  echo "== Bloc compileSdk=36 ajouté en fin de fichier : $file =="
}
add_compile_sdk_override "android/app/build.gradle.kts" "// QHSE MIBEM: compileSdk override (file_picker requires >=36)" "compileSdk = 36"
add_compile_sdk_override "android/app/build.gradle" "// QHSE MIBEM: compileSdk override (file_picker requires >=36)" "compileSdkVersion 36"

for GRADLE_FILE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE_FILE" ]; then
    echo "== Contenu compileSdk final dans $GRADLE_FILE =="
    grep -n "compileSdk" "$GRADLE_FILE" || echo "  (aucune ligne compileSdk trouvée)"
  fi
done

CMAKE="windows/runner/CMakeLists.txt"
if [ -f "$CMAKE" ]; then
  sed -i 's/set(BINARY_NAME "qhse_mobile")/set(BINARY_NAME "QHSE_MIBEM")/' "$CMAKE" || true
fi

echo "== Socle Flutter prêt =="
