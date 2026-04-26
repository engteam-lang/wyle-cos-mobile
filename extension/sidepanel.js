// 1. Manually satisfy the Skwasm import that is crashing the app
// window._flutter_skwasmInstance = {
//   wasmExports: {},
//   wasmMemory: new WebAssembly.Memory({ initial: 256 }),
// };

// window._flutter = {
//   buildConfig: {
//     "engineRevision": "59aa584fdf100e6c78c785d8a5b565d1de4b48ab",
//     "builds": [
//       {
//         "compileTarget": "dart2wasm",
//         "renderer": "canvaskit",
//         "mainWasmPath": "main.dart.wasm",
//         "jsSupportRuntimePath": "main.dart.mjs"
//       }
//     ]
//   }
// };

window.flutterConfiguration = {
  renderer: "canvaskit",
  hostElement: document.querySelector('#flutter_app_container'),
  assetBase: "flutter/",
  entrypointBaseUrl: "flutter/",
  useLocalCanvasKit: true,
  canvasKitBaseUrl: "flutter/canvaskit/",
  // Force browser detection to fail for Skwasm
  // wasmAllowList: { "blink": false, "gecko": false, "webkit": false, "unknown": false }
};

window.addEventListener('load', function (ev) {
  if (window._flutter && window._flutter.loader) {
    _flutter.loader.load({ config: window.flutterConfiguration });
  }
});