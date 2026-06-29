# MiniSheet iOS App

A minimal native iOS wrapper that loads `index.html` (and its fonts/icons)
directly from the app bundle in a `WKWebView`. No server, no network calls.

## Opening in Xcode

1. Pull this branch and open `ios/MiniSheet.xcodeproj` in Xcode.
2. Select the `MiniSheet` target, go to **Signing & Capabilities**, and pick
   your own Apple Developer team. Change `PRODUCT_BUNDLE_IDENTIFIER` (currently
   `com.craigiest.minisheet`) to something under your own identifier prefix if
   needed.
3. Pick a simulator or your device as the run destination and hit Run.

## Project layout

- `MiniSheet/MiniSheetApp.swift` — app entry point (SwiftUI).
- `MiniSheet/ContentView.swift` — wraps a `WKWebView` that loads
  `WebContent/index.html` via `loadFileURL`.
- `MiniSheet/WebContent/` — a copy of `index.html`, `fonts/`, `icons/`, and
  `manifest.webmanifest` from the repo root. This is what actually ships in
  the app.
- `MiniSheet/Assets.xcassets/` — app icon (from `icons/icon-1024.png`) and
  accent color.

## Updating the bundled web app

`WebContent/` is a **copy**, not a symlink, so Xcode can bundle it as a
resource. After editing `index.html` (or `fonts/`/`icons/`) at the repo root,
sync the copy and rebuild:

```sh
./ios/sync-web-content.sh
```

## Before submitting to the App Store

- `icons/icon-1024.png` currently has an alpha channel. App Store Connect
  requires the 1024x1024 marketing icon to be fully opaque (no transparency).
  Flatten it onto an opaque background (e.g. in Preview, Photoshop, or
  `magick icon-1024.png -background white -alpha remove icon-1024-opaque.png`)
  and swap it into `Assets.xcassets/AppIcon.appiconset/`, or Xcode/App Store
  Connect validation will reject the build.
- Set a real bundle identifier and signing team (see step 2 above).
- Consider whether you want `UISupportedInterfaceOrientations` restricted to
  portrait only, or to also allow landscape — currently set to portrait
  (+ all orientations on iPad) in the target's build settings.
- The web app tries to register `sw-test.js` as a service worker on load.
  That file isn't bundled, and service workers aren't available under
  `file://` anyway, so this silently no-ops — harmless, but you can remove
  that script block from `index.html` if you want a cleaner console.
