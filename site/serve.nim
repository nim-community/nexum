## Helix Dev Server
##
## Serves the dist/ directory for local development.
## Auto-picks the first free port starting at 3000.
## Run: nim c -r site/serve.nim

import std/[asynchttpserver, asyncdispatch, strutils, os, mimetypes, uri]

const distDir = "dist"
const startPort = 3000

proc serveFile(path: string): Future[string] {.async.} =
  try:
    result = readFile(path)
  except:
    result = ""

proc handleRequest(req: Request) {.async, gcsafe.} =
  var reqPath = decodeUrl(req.url.path)
  if reqPath == "/":
    reqPath = "/index.html"

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

  let body = await serveFile(filePath)
  let headers = newHttpHeaders([("Content-Type", contentType)])
  await req.respond(Http200, body, headers)

proc runServer() =
  for p in startPort..65535:
    var server = newAsyncHttpServer()
    try:
      echo "Serving http://localhost:" & $p & " (press Ctrl+C to stop)"
      waitFor server.serve(Port(p), handleRequest)
      return
    except OSError as e:
      if "Address already in use" in e.msg:
        continue
      raise
    except:
      raise

runServer()
