import helix/core/signals

var runs = 0
let s = signal(42)
createEffect(proc() =
  discard s()
  inc runs
)
assert runs == 1
s.set(42)  # same value
assert runs == 1  # should NOT re-run
s.set(100)
assert runs == 2
