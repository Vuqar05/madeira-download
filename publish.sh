#!/bin/sh
# Publish a Madeira IPA as the latest release and point the install manifest at it.
# Usage: ./publish.sh path/to/Madeira.ipa ["release notes"]
set -eu
IPA=$1
NOTES=${2:-}
cd "$(dirname "$0")"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -p "$IPA" 'Payload/Madeira.app/Info.plist' > "$TMP/Info.plist"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$TMP/Info.plist")
BUILD=$(plutil -extract CFBundleVersion raw "$TMP/Info.plist")
BUNDLE=$(plutil -extract CFBundleIdentifier raw "$TMP/Info.plist")
TAG="v$VERSION-$BUILD-$(date +%Y%m%d%H%M)"
OWNER=${REPO%/*}
NAME=${REPO#*/}
PAGES="https://$(echo "$OWNER" | tr 'A-Z' 'a-z').github.io/$NAME"

mkdir -p manifests
cat > "manifests/$TAG.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key><string>software-package</string>
          <key>url</key><string>https://github.com/$REPO/releases/download/$TAG/Madeira.ipa</string>
        </dict>
        <dict>
          <key>kind</key><string>display-image</string>
          <key>url</key><string>$PAGES/icon-57.png</string>
        </dict>
        <dict>
          <key>kind</key><string>full-size-image</string>
          <key>url</key><string>$PAGES/icon-512.png</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key><string>$BUNDLE</string>
        <key>bundle-version</key><string>$VERSION</string>
        <key>kind</key><string>software</string>
        <key>title</key><string>Madeira</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

# manifest.plist always installs the latest release
cp "manifests/$TAG.plist" manifest.plist

cp "$IPA" "$TMP/Madeira.ipa"
gh release create "$TAG" "$TMP/Madeira.ipa" --title "Madeira $VERSION ($BUILD)" --notes "$NOTES" --latest
git add manifest.plist "manifests/$TAG.plist"
git commit -qm "Install manifest for $TAG" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -q
echo "Released $TAG"
echo "Page: $PAGES/"
