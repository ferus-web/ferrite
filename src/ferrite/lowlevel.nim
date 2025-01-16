template withUncheckedArray*[T](vector: seq[T], body: untyped) =
  var mem = cast[ptr UncheckedArray[T]](when compileOption("threads"):
    allocShared(vector.len * sizeof(T))
  else:
    alloc(vector.len * sizeof(T)))

  for i, value in vector:
    mem[i] = deepCopy(value)

  var data {.inject.} = ensureMove(mem)
  body

  when not compileOption("threads"):
    deallocShared(data)
  else:
    dealloc(data)
