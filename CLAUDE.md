# MiniSheet

## Versioning

Every commit that changes `full.html` must bump the version number — increment
the patch number in both the `version-tag` and `version-tag-settings` `<span>`
strings (e.g. `v0.0.21` → `v0.0.22`). Do this automatically; do not ask first.

`index.html` (Formulo Lite) is a near-duplicate of `full.html` and shares the
same version number. Whenever `full.html`'s version is bumped, apply the same
new version to `index.html`'s `version-tag`/`version-tag-settings` spans too
(unless the commit's changes are exclusively lite-only behavior, in which case
bump `index.html` alone). Do this automatically; do not ask first.
