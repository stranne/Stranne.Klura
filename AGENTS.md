# Repository agent guidelines

These instructions apply to the entire repository.

## Project

Klura is a personal, non-commercial Flutter web app with small daily logic
puzzles. The goal is a simple, smooth and calm experience. The puzzles are
Bridges and Tents; read [docs/bridges.md](docs/bridges.md) or
[docs/tents.md](docs/tents.md) before working on one of them. A third,
Logjam, has its logic but no screen yet; read [docs/logjam.md](docs/logjam.md)
before working on it.

- Target the web only. Do not add iOS, Android or desktop platforms unless the
  user asks; `flutter create --platforms <list> .` adds them later.
- Keep scope small. Prefer finishing one polished puzzle over a general puzzle
  framework. Add shared abstractions only when a second puzzle needs them.
- Create original puzzles, visuals and text. Do not copy puzzles, art or
  layouts from published puzzle apps.
- Before proposing or adding a puzzle, read
  [docs/mental-gym.md](docs/mental-gym.md): a new puzzle must mainly train a
  skill that no existing puzzle does.
- Never claim that Klura improves memory or thinking, or that it slows
  decline or protects against dementia.

## Code

- Keep each puzzle's rules, generator and solver in
  `lib/puzzles/<name>/logic/`, free of Flutter so they stay fast to test and
  run unchanged on every web target. The same applies to `lib/core/`.
  `test/architecture_test.dart` enforces this and the `SeededRandom` rule.
- Puzzle generation must be deterministic across the VM, JavaScript and
  WebAssembly. Use `SeededRandom` only, never `dart:math` `Random` or
  `List.shuffle`, and keep integer arithmetic within 32 bits.
- Build daily seeds with `dailySeedKey`. Increase the generator version when a
  change would alter the puzzle produced for an existing key.
- Use package imports, `final` locals and typed domain models. The analyzer
  configuration is strict; fix lints rather than suppressing them. Suppress a
  rule only for a specific line, with a short reason in a comment above it.

## Web

- The app is hosted on GitHub Pages at `https://klura.stranne.se/`. CI takes
  the base href from the Pages settings, so the build also works under a
  repository path. Keep URLs in `web/` relative to the base href, and keep
  Flutter's default hash URLs; path URLs need server rewrites that GitHub
  Pages does not offer.
- `web/index.html` sets a content security policy that lets the page load
  files from its own site only, so CanvasKit and the Roboto font are served
  from the site too. Keep new resources on the site rather than widening the
  policy; `test/app/web_shell_test.dart` checks it.
- `web/index.html` shows a loading screen in the theme's surface and primary
  colors. `test/app/web_shell_test.dart` fails when they drift from
  `lib/app/klura_theme.dart`, so update both together.
- The icon sources are the SVG files in `design/icon/`. Edit those and run
  `dart run tool/generate_icons.dart`; never edit the generated icons in
  `web/` by hand.

## Verification

Run every gate before considering work complete:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Flutter-free tests import `package:test`, not `flutter_test`, so they also run
compiled to JavaScript and WebAssembly. When generation, seeding or random code
changes, run `dart test -p node -c dart2js,dart2wasm` on those tests
(`test/core` and each puzzle's logic tests).
Do not use `flutter test --platform chrome` here; it stalls on this machine.
For visible UI changes, run the app in Chrome and check the result.

`.github/workflows/ci.yml` runs the same gates on GitHub and deploys `main`
to GitHub Pages. When the project moves to a new Flutter version, update
`FLUTTER_VERSION` there too.

## Git

- Inspect `git status`, diffs and recent history before committing.
- Create a local commit by default when requested work is complete and
  verified. Use a Conventional Commit title.
- Do not push unless the user asks. Never commit build output or secrets.
