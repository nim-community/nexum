## Nexum Scope — Lifecycle and cleanup management.

import signals

type
  Scope* = ref object
    parent*: Scope
    cleanups*: seq[CleanupFn]
    effects*: seq[Effect]
    disposed*: bool

var currentScope*: Scope = nil

proc newScope*(parent: Scope = nil): Scope =
  Scope(parent: parent)

proc onCleanup*(fn: CleanupFn) =
  if currentScope != nil:
    currentScope.cleanups.add(fn)

proc onMount*(fn: proc()) =
  ## Runs after the component's DOM is attached.
  ## TODO: integrate with hydration mount phase
  when defined(js):
    fn()
  else:
    discard

proc dispose*(s: Scope) =
  if s.disposed: return
  s.disposed = true
  for e in s.effects:
    e.disposed = true
    cleanupEffect(e)
  for cl in s.cleanups:
    cl()
  s.cleanups.setLen(0)

proc runInScope*[T](s: Scope; body: proc(): T): T =
  let prev = currentScope
  currentScope = s
  result = body()
  currentScope = prev
