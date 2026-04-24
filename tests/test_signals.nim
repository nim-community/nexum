import helix
import std/unittest

suite "Signals":
  test "basic get/set":
    let s = signal(42)
    check s() == 42
    s.set(100)
    check s() == 100

  test "effect tracks signal":
    let s = signal(1)
    var called = 0
    createEffect(proc() =
      discard s()
      inc called
    )
    check called == 1
    s.set(2)
    check called == 2

  test "memo caches computed value":
    let s = signal(5)
    let m = memo(proc(): int = s() * 2)
    check m() == 10
    s.set(7)
    check m() == 14

  test "untrack prevents dependency registration":
    let s = signal(1)
    var called = 0
    createEffect(proc() =
      discard untrack(proc(): int = s())
      inc called
    )
    check called == 1
    s.set(2)
    check called == 1  # effect should not rerun

  test "batch queues updates":
    let a = signal(1)
    let b = signal(2)
    var called = 0
    createEffect(proc() =
      discard a()
      discard b()
      inc called
    )
    check called == 1
    batch(proc() =
      a.set(10)
      b.set(20)
    )
    check called == 2  # should only run once after batch

  test "onCleanup registers cleanup":
    var cleaned = false
    createEffect(proc() =
      onCleanup(proc() =
        cleaned = true
      )
    )
    check cleaned == false
