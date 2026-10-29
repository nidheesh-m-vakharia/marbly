# Contributing

## Setup

```sh
swift run                          # the app, in place
swift test                         # unit tests
cd site && pnpm install && pnpm dev   # the website
```

Marbly hides the real Dock while it runs and restores it on quit, including Ctrl-C.
If it ever gets stuck, see [the guide](https://marbly.click/guide#dock-back).

## Workflow

1. Branch from `main`: `feat/…`, `fix/…`, `chore/…`.
2. Open a pull request. `main` only takes changes through PRs, and CI must pass:
   **App (macOS)** builds and tests the Swift package, **Site** builds the website,
   and **Conventional title** checks the PR title.
3. PRs are squash-merged, so the PR title becomes the commit. Write it as
   `type(scope): summary` starting in lower case (acronyms like CI are fine), e.g. `fix(dock): restore tile size on quit`.
   Types: `feat fix perf refactor style docs test build ci chore`.
   Scopes: `app site sound dock settings repo`.

## Design rules

The app and site share one design system; keep new UI inside it.

- **Colour:** Radix slate for neutrals, indigo for selection and the primary action.
  Flat grey surfaces, no outlines, no glass.
- **Type:** Open Runde, four sizes on a minor-second scale from 16 px (14.05, 16,
  18.22, 20.74), weights 400 and 500 (600 only for window numbers on keys),
  Inter Dynamic Metrics tracking, 1.4 line height.
- **Icons:** Solar, Bold style only. Add one with `scripts/fetch_solar_icons.py`.
- **Motion:** answers the user; entrances ease out, exits are quicker; respect
  Reduced Motion.
- **Copy:** sentence case, specific labels, a muted description on every setting.

## Performance rules

Marbly sits in memory all day, so: nothing polls (use notifications and file
watches), the audio engine stops when idle, caches are bounded, and the board
only redraws when its state changes. Note memory and CPU in the PR if you touch
any of that.
