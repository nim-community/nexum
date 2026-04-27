## Nexum CLI — Framework dev tool
##
## Usage:
##   nexum_cli build [options]
##   nexum_cli serve [options]
##
## Auto-detects project layout. Zero config for standard projects.
##
## Standard layout:
##   site/index.nim      or pages/index.nim  — page component (exports indexPage)
##   client.nim          or site/client.nim  — client entry (optional)
##   public/             or static/          — static assets (optional)
##   dist/                                   — build output

import std/[os, strutils, parseopt, times, mimetypes, uri,
            asyncdispatch, asynchttpserver, asyncnet]

proc quitClean() {.noconv.} =
  echo ""
  quit(0)

setControlCHook(quitClean)

const distDir = "dist"
const startPort = 3000


type Project = object
  pageModule: string      # e.g. "site/index" or "pages/index"
  pageProc: string        # e.g. "indexPage"
  client: string          # e.g. "site/client.nim"
  assetsDir: string       # e.g. "public"
  hasCustomBuild: bool    # true if build.nim exists

type CliConfig = object
  cmd: string
  port: int
  outDir: string

proc detectProject(): Project =
  # Custom build script takes precedence
  if fileExists("build.nim"):
    result.hasCustomBuild = true
    result.client =
      if fileExists("client.nim"): "client.nim"
      elif fileExists("site/client.nim"): "site/client.nim"
      else: ""
    result.assetsDir =
      if dirExists("public"): "public"
      elif dirExists("static"): "static"
      else: ""
    return

  # Page module detection
  if fileExists("site/index.nim"):
    result.pageModule = "site/index"
    result.pageProc = "indexPage"
  elif fileExists("pages/index.nim"):
    result.pageModule = "pages/index"
    result.pageProc = "indexPage"
  elif fileExists("app.nim"):
    result.pageModule = "app"
    result.pageProc = "indexPage"

  # Client entry detection
  result.client =
    if fileExists("client.nim"): "client.nim"
    elif fileExists("site/client.nim"): "site/client.nim"
    else: ""

  # Assets detection
  result.assetsDir =
    if dirExists("public"): "public"
    elif dirExists("static"): "static"
    else: ""

proc parseCli(): CliConfig =
  result.outDir = distDir
  result.port = startPort
  var p = initOptParser(commandLineParams())
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if result.cmd.len == 0:
        result.cmd = key
      else:
        echo "Unknown argument: ", key
        quit(1)
    of cmdLongOption, cmdShortOption:
      case key
      of "out", "o": result.outDir = val
      of "port", "p": result.port = parseInt(val)
      else:
        echo "Unknown option: ", key
        quit(1)
    of cmdEnd: discard
  if result.cmd.len == 0:
    result.cmd = "serve"


proc runCustomBuild(project: Project; outDir: string): int =
  echo "[nexum] Running custom build: build.nim"
  let binName = outDir / "_nexum_build"
  let compileCmd = "nim c --path:src -o:" & binName & " build.nim"
  let compileExit = execShellCmd(compileCmd)
  if compileExit != 0:
    echo "[nexum] Build script compilation failed"
    return compileExit
  let runExit = execShellCmd(binName)
  removeFile(binName)
  if runExit != 0:
    echo "[nexum] Build script failed"
    return runExit
  result = 0

proc runGeneratedBuild(project: Project; outDir: string): int =
  let genPath = outDir / "nexum_build.nim"
  var genSrc = ""
  genSrc.add("import std/os\n")
  genSrc.add("import " & project.pageModule & "\n\n")
  genSrc.add("proc main() =\n")
  genSrc.add("  let distDir = \"" & outDir & "\"\n")
  genSrc.add("  if not dirExists(distDir):\n")
  genSrc.add("    createDir(distDir)\n")
  genSrc.add("  let html = \"<!DOCTYPE html>\\n\" & " & project.pageProc & "()\n")
  genSrc.add("  writeFile(distDir / \"index.html\", html)\n")
  genSrc.add("  echo \"HTML built: \" & distDir / \"index.html\"\n\n")
  genSrc.add("main()\n")
  writeFile(genPath, genSrc)

  let binName = outDir / "_nexum_build"
  let compileCmd = "nim c --path:. --path:src -o:" & binName & " " & genPath
  echo "[nexum] Generating site from ", project.pageModule
  let compileExit = execShellCmd(compileCmd)
  removeFile(genPath)
  if compileExit != 0:
    echo "[nexum] Site generation failed"
    return compileExit

  let runExit = execShellCmd(binName)
  removeFile(binName)
  if runExit != 0:
    echo "[nexum] Site generation failed"
    return runExit
  result = 0

proc runBuild(project: Project; config: CliConfig): int =
  if not dirExists(config.outDir):
    createDir(config.outDir)

  # HTML generation
  if project.hasCustomBuild:
    result = runCustomBuild(project, config.outDir)
  elif project.pageModule.len > 0:
    result = runGeneratedBuild(project, config.outDir)
  else:
    echo "[nexum] Warning: no page module found (expected site/index.nim, pages/index.nim, or app.nim)"

  if result != 0:
    return result

  # Client JS
  if project.client.len > 0 and fileExists(project.client):
    let clientOut = config.outDir / "client.js"
    let jsCmd = "nim js --path:\"src\" --path:\".\" -o:" & clientOut & " " & project.client
    echo "[nexum] Compiling client: ", project.client
    let jsExit = execShellCmd(jsCmd)
    if jsExit != 0:
      echo "[nexum] Client compilation failed"
      return jsExit

  # Copy style.css from page module directory (e.g. site/style.css)
  if project.pageModule.len > 0:
    let pageDir = project.pageModule.splitFile.dir
    let cssSrc = pageDir / "style.css"
    let cssDst = config.outDir / "style.css"
    if fileExists(cssSrc) and not fileExists(cssDst):
      copyFile(cssSrc, cssDst)

  # Copy assets (skip Nim source files)
  if project.assetsDir.len > 0 and dirExists(project.assetsDir):
    for file in walkDirRec(project.assetsDir):
      let ext = file.splitFile.ext.toLowerAscii
      if ext in [".nim", ".nims", ".cfg", ".h", ".c", ".cpp"]:
        continue
      let relPath = file[project.assetsDir.len + 1 .. ^1]
      let dst = config.outDir / relPath
      createDir(dst.splitFile.dir)
      copyFile(file, dst)

  echo "[nexum] Build complete: ", config.outDir
  result = 0

proc cmdBuild() =
  let config = parseCli()
  let project = detectProject()
  let exitCode = runBuild(project, config)
  if exitCode != 0:
    quit(exitCode)


type BuildState = ref object
  buildOk: bool
  buildError: string
  lastBuild: float
  clients: seq[Future[void]]

var gState: BuildState

proc state(): BuildState =
  {.cast(gcsafe).}: result = gState

proc setBuildResult(ok: bool; err: string = "") {.gcsafe.} =
  let s = state()
  s.buildOk = ok
  s.buildError = err
  s.lastBuild = epochTime()
  for fut in s.clients:
    if not fut.finished:
      fut.complete()
  s.clients = @[]

proc notifyReload() {.gcsafe.} =
  let s = state()
  for fut in s.clients:
    if not fut.finished:
      fut.complete()
  s.clients = @[]

proc collectWatchedFiles(project: Project; config: CliConfig): seq[string] =
  result = @[]
  for file in walkDirRec("src"):
    if file.endsWith(".nim"):
      result.add(file)
  if project.hasCustomBuild and fileExists("build.nim"):
    result.add("build.nim")
  # Watch all .nim files in the page module directory
  if project.pageModule.len > 0:
    let pageDir = project.pageModule.splitFile.dir
    if dirExists(pageDir):
      for file in walkDirRec(pageDir):
        if file.endsWith(".nim"):
          result.add(file)
        elif file.endsWith(".css") or file.endsWith(".js"):
          result.add(file)
  if project.client.len > 0 and fileExists(project.client):
    result.add(project.client)
  if project.assetsDir.len > 0 and dirExists(project.assetsDir):
    for file in walkDirRec(project.assetsDir):
      result.add(file)

proc getMtimes(files: seq[string]): seq[float] =
  result = @[]
  for f in files:
    try:
      result.add(getFileInfo(f).lastWriteTime.toUnixFloat)
    except:
      result.add(0.0)

proc watchAndBuild(project: Project; config: CliConfig) {.async.} =
  const watchIntervalMs = 500
  var files = collectWatchedFiles(project, config)
  var mtimes = getMtimes(files)

  while true:
    await sleepAsync(watchIntervalMs)

    let newFiles = collectWatchedFiles(project, config)
    let newMtimes = getMtimes(newFiles)

    var changed = false
    var assetChanged = false
    var codeChanged = false

    if newFiles.len != files.len:
      changed = true
    else:
      for i in 0 ..< newFiles.len:
        if newFiles[i] != files[i] or newMtimes[i] != mtimes[i]:
          changed = true
          let ext = newFiles[i].splitFile.ext.toLowerAscii
          if ext in [".css", ".js", ".png", ".jpg", ".jpeg", ".svg", ".ico",
                     ".woff", ".woff2", ".ttf", ".eot", ".gif", ".webp"]:
            assetChanged = true
          else:
            codeChanged = true
          break

    if not changed:
      continue

    files = newFiles
    mtimes = newMtimes

    if codeChanged:
      echo "[dev] Source changed, rebuilding..."
      let exitCode = runBuild(project, config)
      if exitCode != 0:
        echo "[dev] Build FAILED"
        setBuildResult(false, "Build failed with exit code " & $exitCode)
      else:
        echo "[dev] Build OK — reloading browsers"
        setBuildResult(true)
        notifyReload()
    elif assetChanged:
      echo "[dev] Asset changed, copying..."
      if project.assetsDir.len > 0 and dirExists(project.assetsDir):
        for file in walkDirRec(project.assetsDir):
          let ext = file.splitFile.ext.toLowerAscii
          if ext in [".nim", ".nims", ".cfg", ".h", ".c", ".cpp"]:
            continue
          let relPath = file[project.assetsDir.len + 1 .. ^1]
          let dst = config.outDir / relPath
          createDir(dst.splitFile.dir)
          copyFile(file, dst)
      setBuildResult(true)
      notifyReload()

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

proc handleRequest(req: Request; config: CliConfig) {.async, gcsafe.} =
  var reqPath = decodeUrl(req.url.path)

  if reqPath == "/__dev":
    # Use chunked transfer encoding for proper HTTP/1.1 streaming
    let headerStr = "HTTP/1.1 200 OK\r\n" &
                    "Content-Type: text/event-stream\r\n" &
                    "Cache-Control: no-cache\r\n" &
                    "Connection: keep-alive\r\n" &
                    "Access-Control-Allow-Origin: *\r\n" &
                    "Transfer-Encoding: chunked\r\n" &
                    "\r\n"
    await req.client.send(headerStr)
    var fut = newFuture[void]("sse")
    state().clients.add(fut)
    await fut
    try:
      # Chunked format: hex-size + \r\n + data + \r\n
      await req.client.send("e\r\ndata: reload\n\n\r\n")
      # End chunks
      await req.client.send("0\r\n\r\n")
    except:
      discard
    req.client.close()
    return

  if reqPath == "/":
    reqPath = "/index.html"

  if reqPath == "/index.html":
    let s = state()
    if not s.buildOk and s.buildError.len > 0:
      let headers = newHttpHeaders([
        ("Content-Type", "text/html; charset=utf-8"),
        ("Access-Control-Allow-Origin", "*")
      ])
      await req.respond(Http200, errorHtml(s.buildError), headers)
      return

  let filePath = config.outDir & reqPath

  if not filePath.startsWith(config.outDir):
    let headers = newHttpHeaders([("Access-Control-Allow-Origin", "*")])
    await req.respond(Http403, "Forbidden", headers)
    return

  if not fileExists(filePath):
    let headers = newHttpHeaders([("Access-Control-Allow-Origin", "*")])
    await req.respond(Http404, "Not found: " & reqPath, headers)
    return

  let mimeDb = newMimetypes()
  let ext = filePath.splitFile.ext
  let contentType = mimeDb.getMimetype(ext[1..^1])

  var body = readFile(filePath)
  if contentType == "text/html" and body.find(reloadScript) < 0:
    body = body.replace("</body>", reloadScript & "</body>")

  let headers = newHttpHeaders([
    ("Content-Type", contentType),
    ("Access-Control-Allow-Origin", "*")
  ])
  await req.respond(Http200, body, headers)

proc cmdServe() =
  let config = parseCli()
  let project = detectProject()

  echo "[dev] Initial build..."
  let exitCode = runBuild(project, config)
  gState = BuildState()
  if exitCode != 0:
    echo "[dev] Initial build FAILED — fix errors and save to retry"
    setBuildResult(false, "Initial build failed with exit code " & $exitCode)
  else:
    echo "[dev] Initial build OK"
    setBuildResult(true)

  asyncCheck watchAndBuild(project, config)

  for p in config.port..65535:
    var server = newAsyncHttpServer()
    try:
      echo "[dev] Serving http://localhost:" & $p & " (press Ctrl+C to stop)"
      waitFor server.serve(Port(p), proc(req: Request): Future[void] =
        result = handleRequest(req, config)
      )
      return
    except OSError as e:
      if "Address already in use" in e.msg:
        continue
      raise
    except:
      raise


proc showHelp() =
  echo """Nexum CLI — Compile-time reactive web framework

Usage:
  nexum_cli <command> [options]

Commands:
  build    Compile generator, client JS, and copy assets
  serve    Dev server with file watching and auto-reload

Options:
  --out:<dir>     Output directory (default: dist)
  --port:<port>   Dev server port (default: 3000)

Auto-detected project layout:
  build.nim              — custom build script (takes precedence)
  site/index.nim         — page module (exports indexPage)
  pages/index.nim        — page module (exports indexPage)
  app.nim                — page module (exports indexPage)
  client.nim             — client entry
  site/client.nim        — client entry
  public/                — static assets
  static/                — static assets
"""

when isMainModule:
  let config = parseCli()
  case config.cmd
  of "build": cmdBuild()
  of "serve": cmdServe()
  of "help", "--help", "-h": showHelp()
  else:
    echo "Unknown command: ", config.cmd
    showHelp()
    quit(1)
