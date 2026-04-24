version       = "0.1.0"
author        = "Nexum Contributors"
description   = "Compile-time reactive web framework for Nim with SSR & Islands"
license       = "AGPL-3.0"
srcDir        = "src"

requires "nim >= 2.0.0"

task site, "Build the official site":
  exec "nim c -r --path:src site/build.nim"

task serve, "Serve the site locally for development":
  exec "nim c -r --path:src site/serve.nim"
