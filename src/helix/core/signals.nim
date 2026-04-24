## Helix Signals — Fine-grained reactive core.
## Inspired by Solid.js, adapted for Nim's type system.

{.experimental: "callOperator".}

import std/[sets, sequtils, hashes]

type
  EffectFn* = proc() {.closure.}
  CleanupFn* = proc() {.closure.}

  Effect* = ref object
    fn*: EffectFn
    cleanups*: seq[CleanupFn]
    sources*: HashSet[SourceBase]  ## back-references for unsubscribing
    disposed*: bool

  SourceBase* = ref object of RootObj
    ## Abstract base for Signal, Memo, etc.
    observers*: seq[Effect]
    uid*: int

  Signal*[T] = ref object of SourceBase
    value*: T

  Memo*[T] = ref object of SourceBase
    value*: T
    fn*: proc(): T {.closure.}
    dirty*: bool
    tracker*: Effect

  ReadOptions* = enum
    track  ## default: register this read as a dependency
    untrack ## read without subscribing

var
  currentEffect*: Effect = nil
  effectQueue*: seq[Effect] = @[]
  queueScheduled*: bool = false
  batchDepth*: int = 0
  sourceUidCounter*: int = 0

# ---------------------------------------------------------------------------
# Hash support for ref objects in HashSet
# ---------------------------------------------------------------------------

proc hash*(x: SourceBase): Hash =
  x.uid

# ---------------------------------------------------------------------------
# Internal: scheduling
# ---------------------------------------------------------------------------

when defined(js):
  proc scheduleRun(callback: proc()) {.importjs: "queueMicrotask(#)".}
else:
  proc scheduleRun(callback: proc()) =
    ## On native targets, run synchronously for now.
    callback()

proc flushEffects*() =
  queueScheduled = false
  while effectQueue.len > 0:
    let e = effectQueue[0]
    effectQueue.delete(0)
    if not e.disposed:
      e.fn()

proc queueEffect(e: Effect) =
  if e notin effectQueue:
    effectQueue.add(e)
  if batchDepth == 0 and not queueScheduled:
    queueScheduled = true
    scheduleRun(flushEffects)

# ---------------------------------------------------------------------------
# Source / Observer graph
# ---------------------------------------------------------------------------

proc addObserver*(s: SourceBase; e: Effect) =
  if e notin s.observers:
    s.observers.add(e)
  if s notin e.sources:
    e.sources.incl(s)

proc removeObserver*(s: SourceBase; e: Effect) =
  s.observers.keepItIf(it != e)

proc cleanupEffect*(e: Effect) =
  for src in e.sources:
    src.removeObserver(e)
  e.sources.clear()
  for cl in e.cleanups:
    cl()
  e.cleanups.setLen(0)

# ---------------------------------------------------------------------------
# Signal API
# ---------------------------------------------------------------------------

proc signal*[T](value: T): Signal[T] =
  inc sourceUidCounter
  Signal[T](value: value, uid: sourceUidCounter)

proc get*[T](s: Signal[T]; opt = track): T =
  if opt == track and currentEffect != nil:
    addObserver(s, currentEffect)
  s.value

proc set*[T](s: Signal[T]; value: T) =
  when compiles(s.value == value):
    if s.value == value: return
  s.value = value
  # Snapshot observers to allow mutation during iteration
  let obs = s.observers
  for e in obs:
    queueEffect(e)

proc `()`*[T](s: Signal[T]): T = s.get()
proc `()=`*[T](s: Signal[T]; value: T) = s.set(value)

proc get*[T](m: Memo[T]): T =
  if currentEffect != nil:
    addObserver(m, currentEffect)
  if m.dirty:
    cleanupEffect(m.tracker)
    let prev = currentEffect
    currentEffect = m.tracker
    m.value = m.fn()
    currentEffect = prev
    m.dirty = false
  m.value

proc `()`*[T](m: Memo[T]): T = m.get()

# Syntactic sugar helpers for DSL
proc value*[T](s: Signal[T]): T = s.get(track)

# ---------------------------------------------------------------------------
# Effect / Memo
# ---------------------------------------------------------------------------

proc createEffect*(fn: EffectFn) =
  let e = Effect(fn: fn)
  proc run() =
    cleanupEffect(e)
    let prev = currentEffect
    currentEffect = e
    fn()
    currentEffect = prev
  run()

proc memo*[T](fn: proc(): T {.closure.}): Memo[T] =
  inc sourceUidCounter
  let m = Memo[T](dirty: true, uid: sourceUidCounter)
  m.tracker = Effect(fn: proc() =
    m.dirty = true
    let obs = m.observers
    for o in obs:
      queueEffect(o)
  )
  # Initial evaluation
  let prev = currentEffect
  currentEffect = m.tracker
  m.value = fn()
  currentEffect = prev
  m.fn = fn
  result = m

# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

proc batch*(body: proc()) =
  ## Queues all signal updates inside body and flushes once at the end.
  inc batchDepth
  body()
  dec batchDepth
  if batchDepth == 0 and effectQueue.len > 0:
    flushEffects()

# ---------------------------------------------------------------------------
# Untracked read
# ---------------------------------------------------------------------------

proc untrack*[T](body: proc(): T): T =
  let prev = currentEffect
  currentEffect = nil
  result = body()
  currentEffect = prev
