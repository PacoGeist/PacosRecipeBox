{{flutter_js}}
{{flutter_build_config}}

// Recipe Box registers its own offline service worker (sw.js) in index.html.
// Emoji fonts are served from this site (not Google's CDN) so they work offline.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: new URL('fonts/', document.baseURI).href,
  },
});
