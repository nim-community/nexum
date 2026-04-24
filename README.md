# Nexum

> A compile-time reactive web framework for Nim.  
> Zero virtual DOM. Full SSR. Partial hydration.

Nexum is a next-generation frontend framework that leverages Nim's macro system to do at compile time what other frameworks do at runtime. It generates fine-grained DOM updates from reactive signals, produces server-rendered HTML with island hydration markers, and ships minimal JavaScript to the browser.

## Philosophy

- **Compile-time reactivity**: `buildHtml` is a macro. It analyzes your templates, finds dynamic parts, and generates `Signal` subscriptions that call concrete DOM setters. No VDOM tree, no diff.
- **Isomorphic by default**: The same component code compiles to both a C server binary (emitting HTML strings) and a JS client bundle (mounting/hydrating DOM).
- **Islands architecture**: Static pages ship **zero JS**. Only components marked `{.island.}` are hydrated on the client.

## Quick Start (Vision)

```nim
import nexum

# A reactive component
{.island.}
component Counter:
  var count = signal(0)

  buildHtml:
    button(onclick = () => count += 1):
      text "Clicked "
      text count
      text " times"

# Server entry
proc main() =
  let app = initApp()
  # renderToString integrates with your HTTP server
  echo renderPage(app, Counter())

# Client entry
proc start() =
  let app = initApp()
  startClient(app)
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design document, including:
- Signal-based fine-grained reactivity
- Compile-time client/server code generation
- Hydration without VDOM diff
- Streaming SSR roadmap

## Status

**Experimental / Design phase.**  
Core signal runtime and project skeleton are in place. The `buildHtml` macro compiler and full hydration engine are under active design.

## License

GNU Affero General Public License v3.0 (AGPL-3.0)
