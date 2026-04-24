## Nexum Dev Server
##
## Serves dist/ with auto-rebuild, error overlay, and browser reload.
## Run: nim c -r site/serve.nim

import std/[asynchttpserver, asyncdispatch, asyncnet, strutils, os, osproc, mimetypes, uri, times]

const distDir = "dist"
const startPort = 3000
const watchIntervalMs = 500

# ---------------------------------------------------------------------------
# Build state (shared between watcher and HTTP handler)
# ---------------------------------------------------------------------------

type BuildState = object
  lastBuild: float
  buildOk: bool
  buildError: string
  clients: seq[Future[void]] # SSE clients waiting for reload

type BuildStateRef = ref BuildState
var gState: BuildStateRef

proc state(): BuildStateRef {.gcsafe.} =
  {.cast(gcsafe).}: result = gState

proc setBuildResult(ok: bool; err: string = "") {.gcsafe.} =
  let s = state()
  s.buildOk = ok
  s.buildError = err
  s.lastBuild = epochTime()
  var newClients: seq[Future[void]] = @[]
  for fut in s.clients:
    if not fut.finished:
      fut.complete()
    else:
      newClients.add(fut)
  s.clients = newClients

proc notifyReload() {.gcsafe.} =
  let s = state()
  var newClients: seq[Future[void]] = @[]
  for fut in s.clients:
    if not fut.finished:
      fut.complete()
    else:
      newClients.add(fut)
  s.clients = newClients

# ---------------------------------------------------------------------------
# File watcher
# ---------------------------------------------------------------------------

proc collectWatchedFiles(): seq[string] =
  result = @[]
  for file in walkDirRec("src"):
    if file.endsWith(".nim"):
      result.add(file)
  for file in walkDirRec("site"):
    if file.endsWith(".nim") and not file.endsWith("serve.nim") and not file.endsWith("build.nim") and
        not file.endsWith("dev.nim"):
      result.add(file)

proc getMtimes(files: seq[string]): seq[float] =
  result = @[]
  for f in files:
    try:
      result.add(getFileInfo(f).lastWriteTime.toUnixFloat)
    except:
      result.add(0.0)

proc watchAndBuild() {.async.} =
  var files = collectWatchedFiles()
  var mtimes = getMtimes(files)

  while true:
    await sleepAsync(watchIntervalMs)

    let newFiles = collectWatchedFiles()
    let newMtimes = getMtimes(newFiles)

    var changed = false
    if newFiles.len != files.len:
      changed = true
    else:
      for i in 0 ..< newFiles.len:
        if newFiles[i] != files[i] or newMtimes[i] != mtimes[i]:
          changed = true
          break

    if changed:
      files = newFiles
      mtimes = newMtimes
      echo "[dev] Source changed, rebuilding..."
      let (output, exitCode) = execCmdEx("cd \"" & getCurrentDir() & "\" && nim c -r site/build.nim 2>&1")
      if exitCode != 0:
        echo "[dev] Build FAILED"
        setBuildResult(false, output)
      else:
        echo "[dev] Build OK — reloading browsers"
        setBuildResult(true)
        notifyReload()

# ---------------------------------------------------------------------------
# Error overlay HTML
# ---------------------------------------------------------------------------

proc errorHtml(error: string): string =
  result = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Build Error — Nexum</title>
<style>
  *{box-sizing:border-box;margin:0}
  body{font-family:SF Mono,Monaco,Cascadia Code,monospace;background:#1a1a1a;color:#f4f1ea;padding:2rem;line-height:1.6}
  h1{font-family:Shrikhand,Georgia,serif;font-size:2.5rem;color:#c73e1d;margin-bottom:1rem}
  .badge{display:inline-block;font-size:0.75rem;font-weight:800;text-transform:uppercase;letter-spacing:0.1em;
         color:#b8860b;border:2px solid #444;padding:0.4em 1em;margin-bottom:2rem}
  pre{background:#0c0a09;border:3px solid #444;border-radius:8px;padding:1.5rem;overflow-x:auto;font-size:0.85rem;color:#a8a29e;white-space:pre-wrap}
  .reload{color:#6b6560;margin-top:2rem;font-size:0.9rem}
</style></head><body>
  <h1>Build Error</h1>
  <div class="badge">Nexum Dev Server</div>
  <pre>""" & error.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") & """</pre>
  <div class="reload">Fix the error and save. The page will auto-reload.</div>
</body></html>"""

# ---------------------------------------------------------------------------
# SSE reload script (injected into pages)
# ---------------------------------------------------------------------------

const reloadScript = """
<script>
(function() {
  var es = new EventSource('/__dev');
  es.onmessage = function(ev) {
    if (ev.data === 'reload') location.reload();
  };
  es.onerror = function() { /* reconnects automatically */ };
})();
</script>
"""

# ---------------------------------------------------------------------------
# HTTP handlers
# ---------------------------------------------------------------------------

proc handleRequest(req: Request) {.async, gcsafe.} =
  var reqPath = decodeUrl(req.url.path)

  # SSE endpoint for browser reload
  if reqPath == "/__dev":
    let headers = newHttpHeaders([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache"),
      ("Connection", "keep-alive")
    ])
    await req.respond(Http200, "", headers)
    # Keep connection open until a reload is triggered
    var fut = newFuture[void]("sse")
    state().clients.add(fut)
    await fut
    try:
      await req.client.send("data: reload\n\n")
    except:
      discard
    req.client.close()
    return

  if reqPath == "/":
    reqPath = "/index.html"

  # Check build state for HTML pages
  if reqPath == "/index.html":
    var ok: bool
    var err: string
    ok = state().buildOk
    err = state().buildError
    if not ok and err.len > 0:
      let headers = newHttpHeaders([("Content-Type", "text/html; charset=utf-8")])
      await req.respond(Http200, errorHtml(err), headers)
      return

  let filePath = distDir & reqPath

  if not filePath.startsWith(distDir):
    await req.respond(Http403, "Forbidden")
    return

  if not fileExists(filePath):
    await req.respond(Http404, "Not found: " & reqPath)
    return

  let mime = newMimeTypes()
  let ext = filePath.splitFile.ext
  let contentType = mime.getMimeType(ext[1..^1])

  var body = readFile(filePath)
  # Inject reload script into HTML pages
  if contentType == "text/html" and body.find(reloadScript) < 0:
    body = body.replace("</body>", reloadScript & "</body>")

  let headers = newHttpHeaders([("Content-Type", contentType)])
  await req.respond(Http200, body, headers)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

proc runServer() =
  # Do an initial build
  echo "[dev] Initial build..."
  let (output, exitCode) = execCmdEx("cd \"" & getCurrentDir() & "\" && nim c -r site/build.nim 2>&1")
  gState = BuildStateRef()
  if exitCode != 0:
    echo "[dev] Initial build FAILED — fix errors and save to retry"
    setBuildResult(false, output)
  else:
    echo "[dev] Initial build OK"
    setBuildResult(true)

  # Start file watcher
  asyncCheck watchAndBuild()

  for p in startPort..65535:
    var server = newAsyncHttpServer()
    try:
      echo "[dev] Serving http://localhost:" & $p & " (press Ctrl+C to stop)"
      waitFor server.serve(Port(p), handleRequest)
      return
    except OSError as e:
      if "Address already in use" in e.msg:
        continue
      raise
    except:
      raise

runServer()
