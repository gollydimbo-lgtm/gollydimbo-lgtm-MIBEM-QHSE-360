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
# IMPORTANT : ":file_picker:checkReleaseAarMetadata" échoue sur le sous-module
# du PLUGIN lui-même (géré par Flutter, avec son propre compileSdk via
# flutter.compileSdkVersion = 34), pas sur notre application. Patcher notre
# app/build.gradle.kts ne suffit donc pas : il faut forcer compileSdk au
# niveau racine du projet Android via un bloc "subprojects", qui s'applique
# à TOUS les sous-modules — y compris les plugins comme file_picker.
add_compile_sdk_override() {
  local file="$1" marker="$2" body="$3"
  [ -f "$file" ] || return 0
  grep -qF "$marker" "$file" && return 0 # déjà appliqué
  {
    echo ""
    echo "$marker"
    echo "$body"
  } >> "$file"
  echo "== Correctif compileSdk ajouté en fin de fichier : $file =="
}

# 1) Notre propre module (app) : garde le correctif précédent, sans effet de bord.
add_compile_sdk_override "android/app/build.gradle.kts" \
  "// QHSE MIBEM: compileSdk override (file_picker requires >=36)" \
  'android {
    compileSdk = 36
}'

# 2) TOUS les sous-modules (dont les plugins tiers comme file_picker) : le vrai
# correctif nécessaire. Racine du projet Android = android/build.gradle.kts.
# On utilise plugins.withId(...) et non afterEvaluate : le fichier généré par
# Flutter contient déjà "project.evaluationDependsOn(\":app\")", qui force
# l'évaluation immédiate de :app — afterEvaluate plante alors avec "Cannot
# run Project.afterEvaluate(Action) when the project is already evaluated."
# plugins.withId ne dépend pas de l'ordre d'évaluation, donc pas ce problème.
add_compile_sdk_override "android/build.gradle.kts" \
  "// QHSE MIBEM: force compileSdk=36 sur tous les sous-modules (plugins inclus)" \
  'subprojects {
    plugins.withId("com.android.library") {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
    }
    plugins.withId("com.android.application") {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
    }
}'

for GRADLE_FILE in android/app/build.gradle.kts android/build.gradle.kts; do
  if [ -f "$GRADLE_FILE" ]; then
    echo "== Contenu compileSdk final dans $GRADLE_FILE =="
    grep -n "compileSdk\|BaseExtension" "$GRADLE_FILE" || echo "  (rien trouvé)"
  fi
done

CMAKE="windows/runner/CMakeLists.txt"
if [ -f "$CMAKE" ]; then
  sed -i 's/set(BINARY_NAME "qhse_mobile")/set(BINARY_NAME "QHSE_MIBEM")/' "$CMAKE" || true
fi

echo "== Socle Flutter prêt =="
