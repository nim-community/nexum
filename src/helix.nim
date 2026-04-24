## Helix — Public API
##
## Import this module to access the full Helix framework.

import std/json
export json

# Core (available on both targets)
import helix/core/[signals, scope, context]
export signals, scope, context

# App bootstrap (available on both targets)
import helix/app
export app

when defined(js):
  # Client runtime
  import helix/runtime/[dom, hydrate, patch]
  export dom, hydrate, patch
else:
  # Server runtime
  import helix/server/[renderer, stream]
  export renderer, stream

# Router (isomorphic)
import helix/router
export router

# Component macros
import helix/macros
export macros

# Compiler layer is used implicitly via buildHtml; not re-exported here.
