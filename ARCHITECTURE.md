# Helix Architecture

> A compile-time reactive web framework for Nim.  
> Zero virtual DOM. Full SSR. Partial hydration.

---

## 1. Core Philosophy

Karax and most legacy frameworks rely on **Virtual DOM + diff**.  
Helix abandons this entirely in favor of **compile-time reactivity**:

- At compile time, Nim macros analyze your component templates.
- They extract **static** vs **dynamic** parts.
- They generate code that wires `Signal[T]` directly to DOM mutations.
- Runtime overhead is reduced to the absolute minimum: a signal change calls a concrete setter (e.g. `node.textContent = ...`).

This is the same architectural direction as **Solid.js** and **Svelte**, but built on Nim's superior macro system and capable of **true isomorphic SSR**.

---

## 2. Architecture Layers

```
┌──────────────────────────────────────────────┐
│  App Layer (User Code)                       │
│  @component, @page, buildHtml, Signal,       │
│  server(), client(), island()                │
└────────────────────┬─────────────────────────┘
                     │
┌────────────────────▼─────────────────────────┐
│  Compiler Layer (Nim Macros)                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Parser   │ │ Analyzer │ │ Codegen  │     │
│  │ (DSL→AST)│ │(DepGraph)│ │(Target)  │     │
│  └──────────┘ └──────────┘ └──────────┘     │
│         Produces:                            │
│         - Client: DOM effect closures        │
│         - Server: HTML string builders       │
└────────────────────┬─────────────────────────┘
                     │
┌────────────────────▼─────────────────────────┐
│  Runtime Layer                               │
│  ┌──────────────┐ ┌──────────────┐          │
│  │ Signals      │ │ DOM Runtime  │          │
│  │ (Reactive)   │ │ (Client JS)  │          │
│  └──────────────┘ └──────────────┘          │
│  ┌──────────────┐ ┌──────────────┐          │
│  │ SSR Renderer │ │ Hydrator     │          │
│  │ (Server C)   │ │ (Client JS)  │          │
│  └──────────────┘ └──────────────┘          │
└──────────────────────────────────────────────┘
```

---

## 3. Key Concepts

### 3.1 Signals

The universal reactive primitive. Everything that can change is a `Signal`.

```nim
type
  Signal*[T] = ref object
    value: T
    effects: seq[Effect]
    # compiled-time metadata: which DOM nodes / attributes depend on me
```

Effects are **auto-tracked** by the compiler. You write normal Nim code; the macro wraps accesses in dependency registration.

### 3.2 Compile-Time / Run-Time Split

Helix does not ship a template compiler to the browser.  
`buildHtml` is a macro that runs at **Nim compile time** and produces two artifacts:

1. **Client artifact** (`nim js`):
   - Raw DOM node creation (`document.createElement`).
   - Signal subscriptions that call specific DOM APIs.
   - Hydration anchors to attach to existing SSR HTML.

2. **Server artifact** (`nim c`):
   - Fast string/appender output (`result.add "<div>"`).
   - No signal runtime; initial values are inlined as strings.
   - Serialization of island boundaries so the client knows what to hydrate.

### 3.3 Islands Architecture

By default, Helix SSR produces **static HTML with zero JavaScript**.  
You opt components into interactivity with the `{.island.}` pragma:

```nim
{.island.}
component Counter:
  var count = signal(0)
  buildHtml:
    button(onclick = () => count += 1):
      text count
```

On the server, this renders the initial HTML and inserts marker comments:

```html
<!--helix-island start="Counter_7a3f" props='{"initial":0}'-->
<button>0</button>
<!--helix-island end="Counter_7a3f"-->
```

On the client, the hydration engine scans for these markers, mounts only the island components, and wires their signals. The rest of the page remains inert static HTML.

### 3.4 Hydration without VDOM

Because Helix knows the exact DOM structure at compile time, hydration is **targeted**:

1. Parse island markers from SSR output.
2. `document.querySelector` the root element directly.
3. Walk the expected node shape once, establishing `Signal → DOM node/attr` bindings.
4. Done. No diff. No second render pass.

If hydration mismatches (server/client output differ), Helix falls back to **client-side island remount** (clearing the island root and rebuilding just that subtree).

---

## 4. Why This Beats Karax (and most VDOM)

| Dimension | Karax | Helix |
|-----------|-------|-------|
| **Reactive Granularity** | Event → full redraw + VDOM diff | Signal → direct DOM mutation |
| **List Updates** | Prefix/suffix naive diff | Keyed diff generated at compile time, or fine-grained signal-per-row |
| **SSR** | String output, no hydration | Streaming SSR + targeted hydration |
| **JS Payload** | VDOM runtime + full app logic | Only island component runtimes + signal core |
| **Memory** | Keeps VNode tree in memory | Keeps only signal graph + live DOM refs |
| **Batching** | Manual `redraw()` | Automatic effect scheduling (microtask queue) |

---

## 5. File Organization

```
helix/
  helix.nimble
  ARCHITECTURE.md
  src/
    helix.nim               # Public API exports
    helix/
      core/
        signals.nim         # Signal[T], Effect, Memo, batch()
        scope.nim           # Effect cleanup, onCleanup, onMount
        context.nim         # Component instance context, prop injection
      compiler/
        parser.nim          # buildHtml AST → internal IR
        analyzer.nim        # Static/dynamic partitioning, dependency graph
        codegen_client.nim  # IR → client DOM + signal wiring
        codegen_server.nim  # IR → server string builder
      runtime/
        dom.nim             # Thin JS DOM wrappers
        patch.nim           # Island mounting, fallback remount
        hydrate.nim         # SSR marker scanning + binding attachment
      server/
        renderer.nim        # renderToString(), renderToStream()
        stream.nim          # Async chunked response helpers
        router.nim          # Server-side route matching
      router.nim            # Isomorphic router (client + server)
      app.nim               # Application bootstrap: startClient(), startServer()
  tests/
    ...
```

---

## 6. Roadmap

1. **Phase 0**: Signal runtime + `buildHtml` client codegen (no SSR)
2. **Phase 1**: Server codegen + `renderToString`
3. **Phase 2**: Hydration markers + island hydration
4. **Phase 3**: Streaming SSR + async data fetching (`load()`)
5. **Phase 4**: DevTools / HMR / error overlay
