# Repository agent guidelines

These instructions apply to the entire repository.

## Project

Klura is a private, non-commercial Flutter web app with small daily logic
puzzles. The goal is a simple, smooth and calm experience. Bridges is the first
puzzle; read [docs/bridges.md](docs/bridges.md) before working on it.

- Target the web only. Do not add iOS, Android or desktop platforms unless the
  user asks; `flutter create --platforms <list> .` adds them later.
- Keep scope small. Prefer finishing one polished puzzle over a general puzzle
  framework. Add shared abstractions only when a second puzzle needs them.
- Create original puzzles, visuals and text. Do not copy puzzles, art or
  layouts from published puzzle apps.

## Code

- Keep puzzle rules, generators and solvers free of Flutter imports so they
  stay fast to test. Code under `lib/core/` must not import Flutter.
- Puzzle generation must be deterministic across the VM, JavaScript and
  WebAssembly. Use `SeededRandom` only, never `dart:math` `Random` or
  `List.shuffle`, and keep integer arithmetic within 32 bits.
- Build daily seeds with `dailySeedKey`. Increase the generator version when a
  change would alter the puzzle produced for an existing key.
- Use package imports, `final` locals and typed domain models. The analyzer
  configuration is strict; fix lints rather than suppressing them. Suppress a
  rule only for a specific line with a short reason.

## Verification

Run every gate before considering work complete:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Flutter-free tests import `package:test`, not `flutter_test`, so they also run
compiled to JavaScript. When generation, seeding or random code changes, run
`dart test -p node` on those tests (`test/core` and each puzzle's logic tests).
Do not use `flutter test --platform chrome` here; it stalls on this machine.
For visible UI changes, run the app in Chrome and check the result.

## Git

- Inspect `git status`, diffs and recent history before committing.
- Create a local commit by default when requested work is complete and
  verified. Use a Conventional Commit title.
- Do not push unless the user asks. Never commit build output or secrets.
