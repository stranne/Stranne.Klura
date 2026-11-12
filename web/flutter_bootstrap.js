{{flutter_js}}
{{flutter_build_config}}

// Same as Flutter's default bootstrap, with two changes. CanvasKit loads
// from this site rather than Google's servers, in every build mode, as the
// content security policy in index.html requires. And the loading screen
// from index.html goes once the app runs. It shares the app's background
// color, so the hand-over shows no flash.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('loading')?.remove();
  },
});
