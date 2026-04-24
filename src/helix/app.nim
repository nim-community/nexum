## Helix App — Application bootstrap.

import router
when defined(js):
  import std/json
  import runtime/[dom, hydrate]

type
  AppConfig* = object
    rootId*: string = "app"         ## DOM root id for client mount
    enableHydration*: bool = true   ## if true, scan for SSR markers
    enableIslands*: bool = true     ## if true, only hydrate marked islands
    port*: int = 3000               ## Server port
    staticDir*: string = "dist"     ## Static files directory

  App* = ref object
    config*: AppConfig

proc initApp*(config = AppConfig()): App =
  App(config: config)

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

when defined(js):
  proc readHydratedData(): string =
    let script = document.querySelector(cstring"#__helix_data")
    if script != nil:
      result = $script.textContent
    else:
      result = ""

  proc startClient*(app: App; renderFn: proc(): Node) =
    ## Client entry point without routing.
    let root = document.querySelector(cstring("#" & app.config.rootId))
    if root == nil:
      raise newException(ValueError, "Root element #" & app.config.rootId & " not found")
    if app.config.enableHydration:
      hydrateDocument()
    else:
      root.innerHTML = ""
      root.appendChild(renderFn())

  proc startClient*(app: App; router: Router) =
    ## Client entry point with isomorphic router.
    let root = document.querySelector(cstring("#" & app.config.rootId))
    if root == nil:
      raise newException(ValueError, "Root element #" & app.config.rootId & " not found")

    proc renderRoute(url: string) =
      let (route, params) = router.match(url)
      if route.loader != nil:
        currentRouteData = route.loader()
      else:
        currentRouteData = ""
      root.innerHTML = ""
      root.appendChild(route.handler(params))

    onNavigate = proc(url: string) =
      renderRoute(url)

    setupPopstateListener()

    if app.config.enableHydration:
      currentRouteData = readHydratedData()
      hydrateDocument()
      let (route, params) = router.match($locationPathname)
      root.innerHTML = ""
      root.appendChild(route.handler(params))
    else:
      renderRoute($locationPathname)

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

else:
  import std/[net, os, mimetypes, strutils]

  proc startServer*(app: App; router: Router) =
    ## Minimal synchronous HTTP server.
    ## Serves static files from `config.staticDir` and routes dynamic
    ## requests through the provided Router.
    let socket = newSocket()
    socket.setSockOpt(OptReuseAddr, true)
    socket.bindAddr(Port(app.config.port))
    socket.listen()

    let mimeDb = newMimetypes()

    echo "Helix server listening on http://localhost:" & $app.config.port

    while true:
      var client = newSocket()
      socket.accept(client)

      var buf = newString(4096)
      let received = client.recv(buf, 4096)
      if received <= 0:
        client.close()
        continue

      let requestLine = buf.splitLines()[0]
      let parts = requestLine.split(' ')
      if parts.len < 2:
        client.close()
        continue

      let path = parts[1]
      let staticPath = app.config.staticDir / path

      var response: string
      if fileExists(staticPath):
        let ext = splitFile(staticPath).ext
        let mime = mimeDb.getMimetype(ext)
        let content = readFile(staticPath)
        response = "HTTP/1.1 200 OK\r\nContent-Type: " & mime & "\r\nContent-Length: " & $content.len & "\r\nConnection: close\r\n\r\n" & content
      else:
        let (route, params) = router.match(path)
        if route.loader != nil:
          currentRouteData = route.loader()
        else:
          currentRouteData = ""
        var html = route.handler(params)
        if currentRouteData.len > 0:
          html.add "<script id=\"__helix_data\" type=\"application/json\">"
          html.add currentRouteData
          html.add "</script>"
        response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: " & $html.len & "\r\nConnection: close\r\n\r\n" & html

      client.send(response)
      client.close()
