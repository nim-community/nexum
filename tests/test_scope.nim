import nexum

# Scope tests use plain assert (like test_signals_equality.nim)
# to avoid unittest template expansion issues.

block:
  # newScope creates empty scope
  let s = newScope()
  assert s.cleanups.len == 0
  assert s.effects.len == 0
  assert s.disposed == false
  assert s.parent == nil

block:
  # newScope with parent
  let parent = newScope()
  let child = newScope(parent)
  assert child.parent == parent

block:
  # runInScope sets and restores currentScope
  let s = newScope()
  assert currentScope == nil
  var inside = false
  runInScope(s, proc() =
    inside = true
    assert currentScope == s
  )
  assert inside == true
  assert currentScope == nil

block:
  # runInScope nests correctly
  let outer = newScope()
  let inner = newScope()
  var outerSeen = false
  var innerSeen = false
  var outerAfterInner = false
  runInScope(outer, proc() =
    outerSeen = (currentScope == outer)
    runInScope(inner, proc() =
      innerSeen = (currentScope == inner)
    )
    outerAfterInner = (currentScope == outer)
  )
  assert outerSeen == true
  assert innerSeen == true
  assert outerAfterInner == true
  assert currentScope == nil

block:
  # onCleanup registers to currentScope
  let s = newScope()
  var cleaned = false
  runInScope(s, proc() =
    onCleanup(proc() = cleaned = true)
  )
  assert s.cleanups.len == 1
  assert cleaned == false

block:
  # onCleanup does nothing when currentScope is nil
  var cleaned = false
  onCleanup(proc() = cleaned = true)
  assert cleaned == false

block:
  # dispose runs all cleanups
  let s = newScope()
  var a = false
  var b = false
  runInScope(s, proc() =
    onCleanup(proc() = a = true)
    onCleanup(proc() = b = true)
  )
  s.dispose()
  assert a == true
  assert b == true
  assert s.disposed == true
  assert s.cleanups.len == 0

block:
  # dispose is idempotent
  let s = newScope()
  var runs = 0
  runInScope(s, proc() =
    onCleanup(proc() = inc runs)
  )
  s.dispose()
  s.dispose()
  s.dispose()
  assert runs == 1

block:
  # dispose marks effects as disposed and stops them from running
  let s = newScope()
  let sig = signal(0)
  var effectRuns = 0
  runInScope(s, proc() =
    createEffect(proc() =
      discard sig()
      inc effectRuns
    )
  )
  assert effectRuns == 1
  s.dispose()
  assert s.effects.len == 0
  sig.set(1)
  assert effectRuns == 1

block:
  # dispose calls effect cleanup functions
  let s = newScope()
  var effectCleaned = false
  runInScope(s, proc() =
    createEffect(proc() =
      onCleanup(proc() = effectCleaned = true)
    )
  )
  assert effectCleaned == false
  s.dispose()
  assert effectCleaned == true

block:
  # nested scopes dispose children independently
  let parent = newScope()
  let child = newScope(parent)
  var parentCleaned = false
  var childCleaned = false
  runInScope(parent, proc() =
    onCleanup(proc() = parentCleaned = true)
  )
  runInScope(child, proc() =
    onCleanup(proc() = childCleaned = true)
  )
  child.dispose()
  assert childCleaned == true
  assert parentCleaned == false
  parent.dispose()
  assert parentCleaned == true

echo "All scope tests passed."
