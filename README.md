# Klura

Small daily logic puzzles for the web, built with Flutter. Each puzzle type
gets a new puzzle every day, generated on the device from the date. Klura is a
private, non-commercial hobby project.

The first puzzle is [Bridges](docs/bridges.md): connect the islands so every
number is met, all islands are linked and no loops form.

## Run

```sh
flutter run -d chrome
```

## Check

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart test -p node test/core
```

The last command runs the Flutter-free tests compiled to JavaScript under
Node.js. They must pass there too, otherwise the web would generate different
puzzles than the VM. It needs Node.js on `PATH`.

`flutter test --platform chrome` currently stalls on this Windows ARM64
machine, and `package:test` cannot yet load WebAssembly tests under Node with
Dart 3.13. The WebAssembly output was checked by hand on 2026-11-11 and matched
the reference values.

## Build

```sh
flutter build web
```

For GitHub Pages, pass the repository path, for example
`flutter build web --base-href /klura/`.

## Layout

| Path | Responsibility |
| --- | --- |
| `lib/app/` | App widget and theme |
| `lib/home/` | Home screen listing the puzzles |
| `lib/core/` | Flutter-free helpers shared by puzzles: seeded random, daily seed keys |
| `lib/puzzles/<name>/` | One folder per puzzle type (Bridges is next) |
| `docs/` | Puzzle rules and design notes |
