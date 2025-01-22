import std/unittest
import ferrite/utf8view

var
  view1 = newUTF8View("Hello there!")
  view2 = newUTF8View(@[0x80'u8])

suite "UTF-8 View":
  test "count codepoints (text)":
    check view1.len == 12

  test "validate (text)":
    check view1.valid() == true

  test "contains (text)":
    check "Hello" in view1 == true
    check "!" in view1 == true

  test "to string (text)":
    check view1.toString == "Hello there!"

  test "count codepoints (malformed)":
    check view2.len == 0

  test "validate (malformed)":
    check view2.valid == false

  test "contains (malformed)":
    check 0x80'u8 in view2
    check 0x7F'u8 notin view2
