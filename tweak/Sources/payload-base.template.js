globalThis.__PYON_LOADER__ = {
    loaderName: "@TWEAK_NAME@",
    loaderVersion: "@PACKAGE_VERSION@",
    hasThemeSupport: true,
    storedTheme: null,
    fontPatch: 2
}

// Load the WebCord bundle from the latest GitHub release
const bundleUrl = "https://raw.githubusercontent.com/revenge-mod/revenge-bundle/main/revenge.js";

(async () => {
    try {
        const res = await fetch(bundleUrl);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const js = await res.text();
        (0, eval)(js);
    } catch (e) {
        console.error("[WebCord] Failed to load bundle:", e);
    }
})();
