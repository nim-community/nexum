import nexum/core/signals

# Test batch defers updates
var count = 0
let s = signal(0)
createEffect(proc() =
  discard s()
  inc count
)
assert count == 1 # initial run

batch(proc() =
  s.set(1)
  s.set(2)
  s.set(3)
  # during batch, effect should NOT have run yet
  assert count == 1
)
# after batch, effect runs once
assert count == 2
