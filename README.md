# Klura

Small daily logic puzzles for the web, built with Flutter. Each puzzle type
gets a new puzzle every day, generated on the device from the date. Klura is a
personal, non-commercial hobby project.

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
dart test -p node -c dart2js,dart2wasm test/core test/puzzles/bridges/logic
```

The last command runs the Flutter-free tests compiled to JavaScript and to
WebAssembly under Node.js. They must pass there too, otherwise the web would
generate different puzzles than the VM. It needs Node.js on `PATH`.

`flutter test --platform chrome` currently stalls on the Windows ARM64
development machine.

To time Bridges generation on the VM, run `dart run tool/benchmark_bridges.dart`.
The script's documentation shows how to run it under Node.js, and
[docs/bridges.md](docs/bridges.md#performance) records the latest numbers.

## Build

```sh
flutter build web
```

For GitHub Pages, pass the repository name as the base path, for example
`flutter build web --base-href /klura/` for `https://<user>.github.io/klura/`.
The app uses hash URLs (`#/...`), which GitHub Pages serves without extra
configuration.

## Deploy

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the checks above
on every push and pull request to `main`. Once they pass on a push to `main`,
or on a manual run on `main`, it builds the app with
`flutter build web --release --base-href /<repository>/` and deploys
`build/web` to GitHub Pages. It installs the Flutter version set in its
`FLUTTER_VERSION`, so update that together with the local SDK.

One-time setup on GitHub:

1. Create an empty repository, without a README, license or `.gitignore`.
   GitHub Pages needs a public repository, or GitHub Pro or higher for a
   private one. The site itself is public either way.
2. Add the remote and push `main`:

   ```sh
   git remote add origin https://github.com/<user>/<repository>.git
   git push -u origin main
   ```

3. In the repository, set Settings → Pages → Build and deployment → Source to
   GitHub Actions.
4. If the first run's Deploy job failed because Pages was not set up yet, run
   the workflow again: Actions → CI → Run workflow, on `main`.

The app is then at `https://<user>.github.io/<repository>/`, and each puzzle
has its own address below it, for example
`https://<user>.github.io/<repository>/#/bridges/normal`.

### Updates and caching

GitHub Pages serves every file with `Cache-Control: max-age=600`. For up to
ten minutes after a deploy, a browser that loaded the app shortly before may
start the previous version from its cache; after that it checks each file
with the server and gets the new one. A page that stays open, such as the app
on a phone's home screen, runs the version it started with until it reloads.
Closing it fully and opening it again picks up the new one.

Nothing keeps an old version beyond that, because Klura has no service
worker. Flutter 3.50 registers one only when `flutter_bootstrap.js` asks for
it, and `web/flutter_bootstrap.js` does not. The build still writes a
`flutter_service_worker.js`, which only removes a worker that an older
Flutter version installed. CanvasKit and the Roboto font come from Google's
servers at versioned addresses, so they never go stale.

The build leaves `--web-content-hash` off. Hashed file names rely on
`index.html` and `flutter_bootstrap.js` being served with `no-cache`, which
GitHub Pages does not offer, and each deploy removes the previous version's
files, so a cached `flutter_bootstrap.js` could ask for files that no longer
exist.

An old copy from the cache may meet saves written by a newer version. A change
to the save format must allow for that, as
[Save format](docs/bridges.md#save-format) describes.

## Icons

The icon is a K whose lower leg has become a dot. Its sources are
`design/icon/icon.svg`, a rounded tile for the favicon and regular icons, and
`design/icon/icon-full-bleed.svg`, a square for maskable and Apple touch icons
where the platform applies its own shape. After editing either, regenerate
the files in `web/`. This needs ImageMagick 7 (`magick`) on `PATH`.

```sh
dart run tool/generate_icons.dart
```

## Layout

| Path | Responsibility |
| --- | --- |
| `lib/app/` | App widget, routes, theme, settings and the browser's local storage |
| `lib/home/` | Home screen listing today's puzzles, their progress and the daily streak |
| `lib/core/` | Flutter-free helpers shared by puzzles: seeded random, daily seed keys, calendar dates, streaks, play times and the `LocalStore` interface |
| `lib/puzzles/<name>/` | One folder per puzzle type, starting with Bridges: its screen, board, controller and timer, with the Flutter-free rules, solver, generator, game state and save format in `logic/` |
| `web/` | Web shell: loading screen, manifest and generated icons |
| `design/icon/` | SVG sources for the icons |
| `tool/` | Development scripts: the icon generator and the Bridges benchmark |
| `docs/` | Puzzle rules and design notes |
| `.github/workflows/` | CI: the checks, and the build and deploy to GitHub Pages |
