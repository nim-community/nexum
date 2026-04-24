## Helix Site Builder
##
## Compiles the official site to static HTML + JS.
## Run: nim c -r site/build.nim

import std/[os, strutils]
import index

let distDir = "dist"
if not dirExists(distDir):
  createDir(distDir)

# Build server HTML
let html = "<!DOCTYPE html>\n" & indexPage()
writeFile(distDir / "index.html", html)

# Copy CSS
let cssSrc = "site/style.css"
let cssDst = distDir / "style.css"
if fileExists(cssSrc):
  copyFile(cssSrc, cssDst)
else:
  echo "Warning: " & cssSrc & " not found"

echo "HTML built: " & distDir / "index.html"

# Build client JS
let clientOut = distDir / "client.js"
let clientCmd = "nim js --path:\"src\" --path:\".\" -o:" & clientOut & " site/client.nim"
echo "Building client bundle: " & clientCmd
let exitCode = execShellCmd(clientCmd)
if exitCode != 0:
  quit("Client build failed with exit code " & $exitCode, exitCode)

echo "Site built in " & distDir & "/"
