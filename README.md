# Klura

Small daily logic puzzles for the web, built with Flutter. Each puzzle type
gets a new puzzle every day, generated on the device from the date. Klura is a
personal, non-commercial hobby project, played at <https://klura.stranne.se/>.

There are three puzzles so far:

- [Bridges](docs/bridges.md): connect the islands so every number is met, all
  islands are linked and no loops form.
- [Tents](docs/tents.md): give every tree a tent of its own beside it, keep
  tents from touching and match the number of tents in each row and column.

- [Logjam](docs/logjam.md): slide logs along their own lines until the
  marked one can float out through the gap in the boom.

[Mental gym](docs/mental-gym.md) compares the skills each puzzle trains and
sets the rule for choosing the next one.

## Run

```sh
flutter run -d chrome
```

In VS Code, install the recommended Flutter extension. Run and Debug then
lists the app in Chrome in debug, profile and release mode, the tests and both
benchmarks. Tasks: Run Task lists each check below, Check to run them all in
order, and tasks to format the code, build the app and generate the icons.
Check is also the default test task.

## Check

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart test -p node -c dart2js,dart2wasm test/core test/puzzles/bridges/logic test/puzzles/tents/logic test/puzzles/logjam/logic
```

The last command runs the Flutter-free tests compiled to JavaScript and to
WebAssembly under Node.js. They must pass there too, otherwise the web would
generate different puzzles than the VM. It needs Node.js on `PATH`.

`flutter test --platform chrome` currently stalls on the Windows ARM64
development machine.

To time generation on the VM, run `dart run tool/benchmark_bridges.dart`,
`dart run tool/benchmark_tents.dart` or `dart run tool/benchmark_logjam.dart`.
The scripts' documentation shows how to run them under Node.js, and
[docs/bridges.md](docs/bridges.md#performance),
[docs/tents.md](docs/tents.md#performance) and
[docs/logjam.md](docs/logjam.md#performance) record the latest numbers.

## Build

```sh
flutter build web
```

To serve the app below a path rather than at the root of a domain, pass the
path as the base, for example `flutter build web --base-href /klura/` for
`https://<user>.github.io/klura/`. The app uses hash URLs (`#/...`), which GitHub Pages serves without extra
configuration.

The page loads files from its own site only. `web/index.html` sets a content
security policy that allows nothing else, so Flutter's two downloads from
Google come from the site instead: `web/flutter_bootstrap.js` loads CanvasKit
from the build's `canvaskit/` folder, and `fonts/roboto/` holds the Roboto
font the web engine would otherwise fetch. A new resource from another site
needs a change to the policy.

## Deploy

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the checks above
on every push and pull request to `main`. Once they pass on a push to `main`,
or on a manual run on `main`, it builds the app in release mode and deploys
`build/web` to GitHub Pages. It takes the base href from the Pages settings:
`/` for a custom domain, `/<repository>/` for
`https://<user>.github.io/<repository>/`. A change to the custom domain
takes effect with the next deploy, so run the workflow again after one. It
installs the Flutter version set in its `FLUTTER_VERSION`, so update that
together with the local SDK.

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

Klura itself runs on a custom domain, which gives it a browser origin of its
own: on `<user>.github.io`, every project site of the account shares one
origin, with its storage and scripts. To set one up:

1. Verify the domain for GitHub Pages under the account's Settings → Pages,
   so no other account can use it.
2. Add a DNS `CNAME` record from the subdomain, such as `klura`, to
   `<user>.github.io`.
3. Enter the subdomain under the repository's Settings → Pages → Custom
   domain, and select Enforce HTTPS once the certificate is ready.
4. Run the workflow again, so the build uses the new base href. Until then,
   the site at the new address cannot find its files.

The old address then redirects to the new one. Saved games and solve times
stay with the address they were made at.

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
Flutter version installed. CanvasKit and the Roboto font come from the site
like every other file, so the same ten minutes apply to them.

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
| `lib/app/` | App widget, routes, theme, settings, and the browser's local storage and audio |
| `lib/home/` | Home screen listing today's puzzles and their progress |
| `lib/core/` | Flutter-free helpers shared by puzzles: seeded random, daily seed keys, calendar dates, play times, grid positions, the game interface, the solve history, the storage of daily games and the `LocalStore` interface |
| `lib/play/` | What every puzzle screen shares: the play timer, the sounds of moves, the controller base, the daily games of one puzzle and the puzzle screen with its clock, sound button, status line, buttons, solved panel and how-to-play sheet |
| `lib/puzzles/<name>/` | One folder per puzzle type, Bridges, Tents and Logjam: its screen, board, controller and daily games, with the Flutter-free rules, solver, generator, game state and save format in `logic/` |
| `web/` | Web shell: loading screen, content security policy, manifest and generated icons |
| `fonts/` | The Roboto font with its license, bundled so the web engine does not download it |
| `design/icon/` | SVG sources for the icons |
| `tool/` | Development scripts: the icon generator and the benchmark of each puzzle |
| `docs/` | Puzzle rules and design notes, and the skills each puzzle trains |
| `.github/workflows/` | CI: the checks, and the build and deploy to GitHub Pages |
| `.vscode/` | VS Code launch configurations, tasks and the recommended extension |
