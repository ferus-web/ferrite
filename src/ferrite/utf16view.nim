import std/[options, unicode]
import ferrite/[unicode_shared, lowlevel]
import pkg/[results, simdutf/bindings]

const
  HighSurrogateMin*: uint16 = 0xD800
  HighSurrogateMax*: uint16 = 0xDBFF
  LowSurrogateMin*: uint16 = 0xDC00
  LowSurrogateMax*: uint16 = 0xDFFF
  ReplacementCodePoint*: uint32 = 0xFFFD
  FirstSupplementaryPlaneCodePoint*: uint32 = 0x10000

func isHighSurrogate*(codeUnit: uint16 | char16_t): bool =
  (codeUnit >= HighSurrogateMin) and (codeUnit <= HighSurrogateMax)

func isLowSurrogate*(codeUnit: uint16 | char16_t): bool =
  (codeUnit >= LowSurrogateMin) and (codeUnit <= LowSurrogateMax)

type UTF16View* = object
  data: seq[char16_t]
  endianness: UTFEndianness

  cachedCpLength: Option[uint64]

func newUtf16View*(
    data: seq[char16_t] = @[], endianness: UTFEndianness
): UTF16View {.inline, raises: [].} =
  UTF16View(data: data, endianness: endianness)

func newUtf16View*(
  data: seq[uint16] = @[], endianness: UTFEndianness
): UTF16View {.inline, raises: [].} =
  UTF16View(data: cast[seq[char16_t]](data), endianness: endianness)

proc newUtf16View*(str: string): UTF16View {.raises: [].} =
  let cstr = cstring(str)
  var
    view: UTF16View
    data = cast[ptr UncheckedArray[char16_t]](alloc(
      utf16LengthFromUtf8(cstr, str.len.csize_t) * uint(sizeof(uint16))
    ))

  let len = convertUtf8ToUtf16LittleEndian(cstr, str.len.csize_t, data)
  view.data.setLenUninit(len) # Allocate `len` number of `uint16` spaces
  for i in 0 ..< len:
    when defined(danger):
      copyMem(view.data[i].addr, data[i].addr, sizeof(char16_t))
    else:
      view.data[i] = cast[char16_t](data[i])

  dealloc(data)

  move(view)

func `==`*(a, b: UTF16View): bool {.inline, raises: [].} =
  ## Compare two views together
  a.data == b.data and a.endianness == b.endianness

func start*(view: UTF16View): char16_t {.inline.} =
  ## Get the initial codepoint for this view.
  view.data[0]

func data*(view: UTF16View): seq[char16_t] {.inline, raises: [].} =
  ## Get the raw UTF-16 codepoint data for this view.
  view.data

iterator items*(view: UTF16View): lent char16_t =
  for codepoint in view.data:
    yield codepoint

func add*(view: var UTF16View, cp: char16_t) {.inline, raises: [].} =
  ## Append a codepoint to this view
  view.data &= cp
  view.cachedCpLength = none(uint64) # Reset the codepoint length cache

func empty*(view: UTF16View): bool {.inline, raises: [].} =
  ## Check whether this view has no data
  view.data.len < 1

proc valid*(view: UTF16View): bool {.inline, raises: [].} =
  withUncheckedArray view.data:
    case view.endianness
    of UTFEndianness.Little:
      result = validateUtf16LittleEndian(data, view.data.len.csize_t)
    of UTFEndianness.Big:
      result = validateUtf16BigEndian(data, view.data.len.csize_t)
    of UTFEndianness.Host:
      result = validateUtf16(data, view.data.len.csize_t)

proc calculateLengthInCodePoints*(view: UTF16View): uint64 {.inline, raises: [].} =
  var length: uint64

  if likely(view.valid):
    withUncheckedArray view.data:
      case view.endianness
      of UTFEndianness.Little:
        length = countUtf16LittleEndian(data, view.data.len.csize_t)
      of UTFEndianness.Big:
        length = countUtf16BigEndian(data, view.data.len.csize_t)
      of UTFEndianness.Host:
        length = countUtf16(data, view.data.len.csize_t)

    return length

  for cp in view:
    inc length

  return length

proc codepointLen*(view: var UTF16View): uint64 {.inline, raises: [].} =
  ## Find out the length of this view, in UTF-16 code points.
  ## This variant of the function caches its result.
  if view.cachedCpLength.isSome:
    return view.cachedCpLength.unsafeGet()

  let len = view.calculateLengthInCodePoints()
  view.cachedCpLength = some(len)
  return len

proc codepointLen*(view: UTF16View): uint64 {.inline, raises: [].} =
  ## Find out the length of this view, in UTF-16 code points.
  ## This variant of the function does not cache its result.
  if view.cachedCpLength.isSome:
    return view.cachedCpLength.unsafeGet()

  view.calculateLengthInCodePoints()

func codeunitLen*(view: UTF16View): uint64 {.inline, raises: [].} =
  ## Find out the length of this view, in UTF-16 code units.
  uint64(view.data.len)

func codeUnitAt*(
    view: UTF16View, index: SomeUnsignedInt
): char16_t {.inline, raises: [].} =
  ## Get the UTF-16 code unit at `index`
  view.data[index]

func decodeSurrogatePair*(high, low: char16_t): uint32 {.inline, raises: [ValueError].} =
  ## Decode a surrogate pair.
  ## `high` must be a high surrogate, and `low` must be a low surrogate.
  ## Otherwise, a `ValueError` will be raised if either of the conditions are not met.
  if not high.isHighSurrogate:
    raise newException(ValueError, $high & " is not a high surrogate")

  if not low.isLowSurrogate:
    raise newException(ValueError, $low & " is not a low surrogate")

  ((high - HighSurrogateMin).uint32 shl 10'u32) + (low - LowSurrogateMin).uint32 +
    FirstSupplementaryPlaneCodePoint

func codePointAt*(
    view: UTF16View, index: SomeUnsignedInt
): uint32 {.raises: [ValueError].} =
  ## Get the code point at `index` in this view.
  if index > view.codeUnitLen:
    raise newException(IndexDefect, "Index " & $index & " is out of range")

  let codePoint = view.codeUnitAt(index)
  if not isHighSurrogate(codePoint) and not isLowSurrogate(codePoint):
    return uint32(cast[uint16](codePoint))

  if isLowSurrogate(codePoint) or (index + 1 == view.codeunitLen()):
    return uint32(cast[uint16](codePoint))

  let second = view.codeUnitAt(index + 1)
  if not isLowSurrogate(second):
    return uint32(cast[uint16](codePoint))

  return decodeSurrogatePair(codePoint, second)

proc toUtf8*(view: UTF16View): string {.raises: [ValueError].} =
  ## Get the UTF-8 representation of this view's contents.
  var
    i = 0'u64
    str: string

  while i < view.codepointLen:
    let codePoint = view.codePointAt(i)
    str &= toUTF8(cast[Rune](codePoint))

    if codePoint >= FirstSupplementaryPlaneCodePoint:
      inc i

    inc i

  move(str)

proc startsWith*(view: UTF16View, needle: UTF16View): bool {.raises: [ValueError].} =
  if needle.empty:
    return true

  if view.empty:
    return false

  if needle.codeUnitLen > view.codeUnitLen:
    return false

  if needle.start == view.start:
    return true

  for i in 0 .. needle.codepointLen:
    let codePoint = view.codePointAt(i)

    if codePoint != needle.codePointAt(i):
      return false

  return true

export unicode_shared, char16_t, `==`
