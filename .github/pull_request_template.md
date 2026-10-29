<!-- Title: type(scope): summary — e.g. "feat(app): number window keys". It becomes the squash commit. -->

## What

<!-- One or two sentences: what changes for someone using Marbly or the site. -->

## Why

<!-- The problem or request behind it. Link an issue if there is one: Closes #123 -->

## How it was checked

- [ ] `swift build` and `swift test` pass
- [ ] Ran the app (`swift run`) and tried the change by hand
- [ ] Quitting restores the macOS Dock (if Dock behaviour changed)
- [ ] `cd site && pnpm build` passes (if the site changed)
- [ ] Light and dark, and Reduced Motion (if UI or motion changed)

## Screenshots

<!-- Before / after for anything visible. `swift run Marbly --snapshot-settings out/` renders every settings page. -->

## Notes for review

<!-- Anything risky, unfinished, or worth a closer look. Delete if none. -->
