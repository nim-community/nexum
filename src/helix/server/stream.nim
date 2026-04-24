## Helix Server — Streaming SSR helpers.
##
## Provides chunked transfer for large pages or async data boundaries.

import renderer

type
  StreamChunk* = object
    html*: string
    ## Future: support out-of-order streaming with Suspense boundaries

proc renderStream*(body: proc(ctx: RenderContext); cb: proc(chunk: string)) =
  ## Calls emit with partial HTML as it becomes available.
  ## Integrates with async HTTP servers (e.g., Prologue, Jester, httpbeast).
  let ctx = newRenderContext()
  body(ctx)
  cb(ctx.buf)
