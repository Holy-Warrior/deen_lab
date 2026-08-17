/**
 * Turns the body markup Groq returns into the complete, self-contained document that a
 * generated feature runs inside.
 *
 * The model is never asked to link Tailwind itself. It is told the classes already work, and
 * this module supplies the runtime. That inverts the trust: instead of hoping the model wrote
 * the right CDN URL (and reached the network to load it), the app guarantees a known-good,
 * version-pinned copy is present every time, online or off.
 */

// The Tailwind runtime is bundled into the app at static/vendor/tailwind-browser.js rather than
// pulled from a CDN, so previews work with no connection and the version can't shift underneath
// us. It is pinned to 4.3.3, matching the app's own Tailwind.
const runtimeUrl = "/vendor/tailwind-browser.js";

let runtimeRequest: Promise<string> | null = null;

/** Fetches the bundled Tailwind runtime once and shares it across every preview. */
export function loadTailwindRuntime(): Promise<string> {
    // caching the promise rather than the text means two previews opened at once share a single
    // fetch instead of racing; on failure the cache is cleared so a retry can actually retry
    runtimeRequest ??= fetch(runtimeUrl)
        .then(response => {
            if (!response.ok) throw new Error(`The Tailwind runtime is missing (${response.status}).`);
            return response.text();
        })
        .catch(error => {
            runtimeRequest = null;
            throw error;
        });

    return runtimeRequest;
}

// csp: the actual guarantee that a generated feature cannot reach the network or touch the app.
// The prompt asks the model to avoid external resources, but a prompt is a request, not a
// control -- this is enforced by the browser regardless of what the model wrote. 'unsafe-inline'
// is unavoidable because everything here is inline by design (the runtime, the stylesheet it
// generates, the feature's own script). 'unsafe-eval' is deliberately absent: the Tailwind
// browser build was checked and uses neither eval nor new Function.
const contentSecurityPolicy = [
    "default-src 'none'",
    "script-src 'unsafe-inline'",
    "style-src 'unsafe-inline'",
    "img-src data:",
    "font-src data:",
    "base-uri 'none'",
    "form-action 'none'"
].join("; ");

/** Marks messages coming from a preview frame, so the app ignores any other page's chatter. */
export const storageMessageSource = "deenlab-feature";

/**
 * Gives the sandboxed frame a working `localStorage`.
 *
 * The frame runs without allow-same-origin, so the real `localStorage` throws a SecurityError on
 * an opaque origin — merely *reading* it takes the whole feature script down. Rather than teach
 * the model a bespoke async API it would have to be told about (and might forget), this restores
 * the ordinary Storage API it already knows, and makes it persist:
 *
 * - **Reads are synchronous**, because the saved data is inlined into the document at compose
 *   time. `getItem` never has to wait for a round trip, which is what makes the standard API
 *   possible at all — postMessage is async and `getItem` is not.
 * - **Writes fire a postMessage** to the app, which stores them against this tool's id.
 *
 * postMessage is the one channel that does cross the sandbox boundary, and it is one-way by
 * construction: the frame can hand data out, but cannot reach in and read anything.
 */
function storageShim(initialState: Record<string, string>): string {
    // < escaping: a stored value containing "</script>" would otherwise close this block
    // early and inject markup into the document
    const inlined = JSON.stringify(initialState ?? {}).replace(/</g, "\\u003c");

    return `(function () {
  var store = ${inlined};

  function persist() {
    try {
      parent.postMessage({ source: ${JSON.stringify(storageMessageSource)}, kind: 'storage', state: store }, '*');
    } catch (error) {}
  }

  var shim = {
    getItem: function (key) { return Object.prototype.hasOwnProperty.call(store, String(key)) ? store[String(key)] : null; },
    setItem: function (key, value) { store[String(key)] = String(value); persist(); },
    removeItem: function (key) { delete store[String(key)]; persist(); },
    clear: function () { store = {}; persist(); },
    key: function (index) { var keys = Object.keys(store); return index < keys.length ? keys[index] : null; },
    get length() { return Object.keys(store).length; }
  };

  try { Object.defineProperty(window, 'localStorage', { value: shim, configurable: true }); } catch (error) {}
  try { Object.defineProperty(window, 'sessionStorage', { value: shim, configurable: true }); } catch (error) {}
})();`;
}

/**
 * Reduces whatever the model returned to markup that belongs inside <body>.
 *
 * The prompt asks for body-only markup and the model reliably complies, but "reliably" is not
 * "always", and a stray <head> would otherwise be rendered as visible text. Anything that would
 * load an external resource is dropped here too -- the CSP would already block it, so this is
 * about not leaving dead nodes and broken-image icons in the DOM.
 */
export function extractBodyMarkup(html: string): string {
    let markup = html.trim();

    const bodyTag = markup.match(/<body[^>]*>/i);
    if (bodyTag) {
        const start = markup.indexOf(bodyTag[0]) + bodyTag[0].length;
        const end = markup.toLowerCase().lastIndexOf("</body>");
        markup = markup.slice(start, end === -1 ? undefined : end);
    } else {
        markup = markup
            .replace(/<!doctype[^>]*>/gi, "")
            .replace(/<\/?html[^>]*>/gi, "")
            .replace(/<head[\s\S]*?<\/head>/gi, "");
    }

    return markup
        .replace(/<link\b[^>]*>/gi, "")
        .replace(/<script\b[^>]*\bsrc\s*=[\s\S]*?<\/script>/gi, "")
        .trim();
}

/** Assembles the full document string handed to the preview iframe's srcdoc. */
export function composeDocument(
    html: string,
    tailwindRuntime: string,
    initialState: Record<string, string> = {}
): string {
    // The plain <style> below runs before Tailwind has compiled anything. Without it the
    // preview flashes white on open, because the runtime generates its stylesheet
    // asynchronously after the document has already painted.
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta http-equiv="Content-Security-Policy" content="${contentSecurityPolicy}">
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; padding: 0; background: #09090b; color: #f4f4f5; }
  body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; -webkit-text-size-adjust: 100%; }
</style>
<script>${storageShim(initialState)}</script>
<script>${tailwindRuntime}</script>
</head>
<body class="bg-zinc-950 text-zinc-100">
${extractBodyMarkup(html)}
</body>
</html>`;
}
