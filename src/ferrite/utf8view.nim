import pkg/simdutf/[unicode, bindings, shared]

type UTF8EncodedByteData = object
  byteLength*: uint
  encodingBits*, encodingMask*: uint8
  firstCodePoint*, lastCodePoint*: uint32

const utf8EncodedByteData: array[4, UTF8EncodedByteData] = [
  UTF8EncodedByteData(
    byteLength: 1,
    encodingBits: 0b0000,
    encodingMask: 0b1000,
    firstCodePoint: 0x0000,
    lastCodePoint: 0x007F,
  ),
  UTF8EncodedByteData(
    byteLength: 2,
    encodingBits: 0b1100,
    encodingMask: 0b1110,
    firstCodePoint: 0x0080,
    lastCodePoint: 0x07FF,
  ),
  UTF8EncodedByteData(
    byteLength: 3,
    encodingBits: 0b1110,
    encodingMask: 0b1111,
    firstCodePoint: 0x0800,
    lastCodePoint: 0xFFFF,
  ),
  UTF8EncodedByteData(
    byteLength: 4,
    encodingBits: 0b1111,
    encodingMask: 0b1111,
    firstCodePoint: 0x10000,
    lastCodePoint: 0x10FFFF,
  ),
]

type UTF8View* = object
  data: seq[uint8]

func toString*(view: UTF8View): string =
  var str = newString(view.data.len)

  for i in 0 ..< view.data.len:
    when defined(danger):
      copyMem(str[i].addr, view.data[i].addr, sizeof(uint8))
    else:
      str[i] = cast[char](view.data[i])

  move(str)

func toCstring*(view: UTF8View): cstring =
  cstring(view.toString())
    # FIXME: I'm pretty sure we can optimize this to avoid the extra allocation...

func newUTF8View*(str: string): UTF8View =
  var data: seq[uint8]
  data.setLenUninit(str.len)

  for i in 0 ..< str.len:
    when defined(danger):
      copyMem(data[i].addr, str[i].addr, sizeof(uint8))
    else:
      data[i] = cast[uint8](str[i])

  UTF8View(data: move(data))

func newUTF8View*(data: seq[uint8]): UTF8View {.inline.} =
  UTF8View(data: data)

proc validate*(view: UTF8View): tuple[valid: bool, count: uint] {.inline.} =
  let res = validateUtf8WithErrors(view.toString())

  (valid: res.error == SimdutfError.Success, count: res.count)

proc valid*(view: UTF8View): bool {.inline.} =
  validateUtf8(view.toString())

func decodeLeadingByte*(
    value: uint8
): tuple[byteLength: uint, codePointBits: uint32, isValid: bool] =
  var value = value
  for data in utf8EncodedByteData:
    if (value and data.encodingMask) != data.encodingBits:
      continue

    value = value and not data.encodingMask
    return (byteLength: data.byteLength, codePointBits: value.uint32(), isValid: true)

  return (byteLength: default(uint), codePointBits: default(uint32), isValid: false)

func len*(view: UTF8View): uint64 =
  if likely(view.valid):
    return countUtf8(view.toCstring(), view.data.len.csize_t)

  var length: uint64
  var i = 0'u

  while i < uint(view.data.len - 1):
    let (byteLength, _, isValid) = decodeLeadingByte(cast[uint8](view.data[i]))

    i += (if isValid: byteLength else: 1)
    inc length

  length

func empty*(view: UTF8View): bool =
  view.data.len < 1

func contains*(view: UTF8View, needle: uint32): bool {.inline.} =
  if view.empty:
    return false

  for codePoint in view.data:
    if codePoint.uint32() == needle:
      return true

func contains*(view: UTF8View, needle: string): bool =
  if view.empty:
    return false

  if needle.len < 1:
    return true

  if needle.len.uint64 > view.len:
    return false

  for pos, codePoint in view.data:
    if codePoint != cast[uint8](needle[0]):
      continue

    if (pos + needle.len - 1) > view.data.len:
      continue

    var failed = false
    for i in 1 ..< needle.len:
      if cast[uint8](view.data[i]) != view.data[pos + i]:
        failed = true
        continue

    if failed:
      break

    return true
