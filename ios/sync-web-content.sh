#!/bin/sh
# Copies the latest web app files from the repo root into the Xcode project's
# bundled WebContent folder. Run this after changing full.html, fonts/, or
# icons/, then rebuild in Xcode.
set -e
cd "$(dirname "$0")/.."

cp full.html ios/MiniSheet/WebContent/full.html
cp manual.html ios/MiniSheet/WebContent/manual.html
cp support.html ios/MiniSheet/WebContent/support.html
cp privacy.html ios/MiniSheet/WebContent/privacy.html
rm -rf ios/MiniSheet/WebContent/fonts ios/MiniSheet/WebContent/icons
cp -r fonts ios/MiniSheet/WebContent/fonts
cp -r icons ios/MiniSheet/WebContent/icons
cp manifest.webmanifest ios/MiniSheet/WebContent/manifest.webmanifest

echo "WebContent synced from repo root."
