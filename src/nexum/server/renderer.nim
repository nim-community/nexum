## Nexum Server — SSR Renderer: component → HTML string.
##
## This module is compiled with the C backend (or JS backend for testing).
## It produces the initial HTML including island markers.

import std/json

type
  RenderOptions* = object
    includeIslandMarkers*: bool ## true for client-facing pages
    pretty*: bool               ## indentation (debug only)

  RenderContext* = ref object
    buf*: string
    opts*: RenderOptions

proc newRenderContext*(opts = RenderOptions(includeIslandMarkers: true)): RenderContext =
  RenderContext(buf: "", opts: opts)

proc write*(ctx: RenderContext; s: string) =
  ctx.buf.add(s)

proc writeEscaped*(ctx: RenderContext; s: string) =
  ## HTML escaping for **attribute values** (double-quoted).
  ## Escapes `&`, `<`, `>`, and `"` so values are safe inside `"..."`.
  for c in s:
    case c
    of '<': ctx.buf.add("&lt;")
    of '>': ctx.buf.add("&gt;")
    of '&': ctx.buf.add("&amp;")
    of '"': ctx.buf.add("&quot;")
    else: ctx.buf.add(c)

proc writeText*(ctx: RenderContext; s: string) =
  ## HTML escaping for **text content** (element children).
  ## Per the HTML spec, only `&`, `<`, and `>` need escaping in text nodes;
  ## `"` is a literal character here and is left untouched. This avoids
  ## needlessly bloating embedded JSON / structured data with `&quot;`.
  for c in s:
    case c
    of '<': ctx.buf.add("&lt;")
    of '>': ctx.buf.add("&gt;")
    of '&': ctx.buf.add("&amp;")
    else: ctx.buf.add(c)

proc writeIslandStart*(ctx: RenderContext; id: string; props: JsonNode) =
  if ctx.opts.includeIslandMarkers:
    ctx.buf.add("<!--nexum-island start=\"")
    ctx.buf.add(id)
    ctx.buf.add("\" props='")
    ctx.buf.add($props)
    ctx.buf.add("'-->")

proc writeIslandEnd*(ctx: RenderContext; id: string) =
  if ctx.opts.includeIslandMarkers:
    ctx.buf.add("<!--nexum-island end=\"")
    ctx.buf.add(id)
    ctx.buf.add("\"-->")

proc renderToString*(body: proc(ctx: RenderContext)): string =
  let ctx = newRenderContext()
  body(ctx)
  ctx.buf
