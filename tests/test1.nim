import std/unittest
import ferrite/utf16view

var
  view =
    newUtf16View(@[0xD83C'u16, 0xDFF3'u16, 0xFE0F'u16, 0x26A7'u16], UTFEndianness.Host)

  view2 = newUtf16View("Hello! How are ya?")

  view3 = newUtf16View(@[0xD800'u16, 0x0041'u16], UTFEndianness.Host)

suite "UTF-16 View":
  test "count codepoints (emoji)":
    check view.codepointLen == 3

  test "convert to UTF-8 (emoji)":
    check view.toUtf8 == "🏳️"

  test "start of view (emoji)":
    check view.start == 0xD83C'u16

  test "validation (emoji)":
    check view.valid() == true

  test "count codepoints (text)":
    check view2.codepointLen == 18

  test "convert to UTF-8 (text)":
    check view2.toUtf8 == "Hello! How are ya?"

  test "validation (text)":
    check view2.valid() == true

  test "validation (invalid UTF-16 sequence)":
    check view3.valid() == false
