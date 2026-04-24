## Nexum — Public API
##
## Import this module to access the full Nexum framework.

import std/json
export json

# Core (available on both targets)
import nexum/core/[signals, scope, context]
export signals, scope, context

# App bootstrap (available on both targets)
import nexum/app
export app

when defined(js):
  # Client runtime
  import nexum/runtime/[dom, hydrate, patch]
  export dom, hydrate, patch
else:
  # Server runtime
  import nexum/server/[renderer, stream]
  export renderer, stream

# Router (isomorphic)
import nexum/router
export router

# Component macros
import nexum/macros
export macros

# Scoped CSS
import nexum/compiler/style
export style

# Compiler layer is used implicitly via buildHtml; not re-exported here.
