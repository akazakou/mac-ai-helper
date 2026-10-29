#!/bin/bash
# ==============================================================================
# Create a persistent self-signed code-signing certificate for GitHub releases.
#
# macOS binds Accessibility / Screen Recording grants and Keychain access to the
# app's designated requirement (bundle ID + signing certificate). Signing every
# release with the same certificate keeps those grants across updates.
# No Apple Developer account is involved; Gatekeeper still treats the app as
# unidentified, so users confirm "Open Anyway" once per downloaded version.
#
# Run once, upload the printed secrets, then store the output folder safely.
# Creating a new certificate later resets all users' permissions once.
#
# Usage: scripts/create-signing-cert.sh [output_dir]
# ==============================================================================

set -euo pipefail

CERT_NAME="Mac AI Helper Code Signing"
VALIDITY_DAYS=7300
REPOSITORY="akazakou/mac-ai-helper"
OUTPUT_DIR="${1:-$HOME/.mac-ai-helper-signing}"
P12_FILE="$OUTPUT_DIR/signing-cert.p12"
PASSWORD_FILE="$OUTPUT_DIR/signing-cert-password.txt"

if [ -e "$P12_FILE" ]; then
    echo "Error: $P12_FILE already exists. Refusing to overwrite the signing identity." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
    -days "$VALIDITY_DAYS" \
    -subj "/CN=$CERT_NAME" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$WORK_DIR/key.pem" \
    -out "$OUTPUT_DIR/signing-cert.pem" 2>/dev/null

# macOS `security import` rejects the OpenSSL 3 default PKCS#12 encryption,
# so the legacy SHA1/3DES algorithms are requested explicitly.
P12_PASSWORD=$(openssl rand -base64 24)
export P12_PASSWORD
openssl pkcs12 -export \
    -inkey "$WORK_DIR/key.pem" \
    -in "$OUTPUT_DIR/signing-cert.pem" \
    -name "$CERT_NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout env:P12_PASSWORD \
    -out "$P12_FILE"

printf '%s' "$P12_PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$P12_FILE" "$PASSWORD_FILE"

echo "✅ Certificate created in $OUTPUT_DIR"
echo ""
echo "Upload it to GitHub Secrets:"
echo "  base64 -i \"$P12_FILE\" | gh secret set MACOS_SIGNING_CERT_P12_BASE64 --repo $REPOSITORY"
echo "  gh secret set MACOS_SIGNING_CERT_PASSWORD --repo $REPOSITORY < \"$PASSWORD_FILE\""
echo ""
echo "Keep $OUTPUT_DIR backed up in a password manager — anyone holding the .p12"
echo "can sign apps that inherit the permissions users granted to Mac AI Helper."
