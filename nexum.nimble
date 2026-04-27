version       = "0.1.0"
author        = "Nexum Contributors"
description   = "Compile-time reactive web framework for Nim with SSR & Islands"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nexum_cli"]

requires "nim >= 2.0.0"

task site, "Build the official site":
  exec "nim c -r --path:src src/nexum_cli.nim build"

task serve, "Serve the site locally for development":
  exec "nim c -r --path:src src/nexum_cli.nim serve"
