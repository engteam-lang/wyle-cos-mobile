window.addEventListener('load', async function () {
    const loader = window._flutter.loader;

    const engineInitializer = await loader.loadEntrypoint({
        entrypointUrl: "flutter/main.dart.js"
    });

    const appRunner = await engineInitializer.initializeEngine({
        renderer: "canvaskit",
        canvasKitBaseUrl: "flutter/canvaskit/",
        assetBase: "flutter/"
    });

    await appRunner.runApp();
});