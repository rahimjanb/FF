#!/usr/bin/env bash
# Creates the Google Play upload key and android/key.properties (both are git-ignored).
# Google re-signs the app with its own key (Play App Signing); this key only proves uploads come from you.
# Keep a copy of the .jks file and the password outside this computer. If it is lost, ask Google Play
# support to reset the upload key (Play Console → Test and release → App integrity).
set -euo pipefail
cd "$(dirname "$0")/.."

KEYSTORE=android/upload-keystore.jks
PROPS=android/key.properties
if [[ -e $KEYSTORE || -e $PROPS ]]; then
  echo "$KEYSTORE or $PROPS already exists; nothing changed." >&2
  exit 1
fi

KEYTOOL=$(command -v keytool || true)
[[ -n $KEYTOOL ]] || KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
[[ -x $KEYTOOL ]] || { echo "keytool not found: install Android Studio or a JDK." >&2; exit 1; }

PASSWORD=$(openssl rand -hex 24)
"$KEYTOOL" -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -alias upload -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$PASSWORD" -keypass "$PASSWORD" -dname "CN=Fitness Formulasi, O=Fitness Formulasi, C=UZ" >/dev/null
umask 077
cat >"$PROPS" <<PROPS
storeFile=upload-keystore.jks
storePassword=$PASSWORD
keyAlias=upload
keyPassword=$PASSWORD
PROPS
chmod 600 "$KEYSTORE"

echo "Created $KEYSTORE and $PROPS."
echo "Back up both files (password manager, encrypted storage) — they are not in git."
"$KEYTOOL" -list -keystore "$KEYSTORE" -storepass "$PASSWORD" -alias upload | grep -i "SHA-256\|SHA256" || true
