{{flutter_js}}
{{flutter_build_config}}

// Same as Flutter's default bootstrap, but removes the loading screen from
// index.html once the app runs. The loading screen shares the app's
// background color, so the hand-over shows no flash.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('loading')?.remove();
  },
});
