import ferrite/utf16view

var view =
  newUtf16View(@[0xD83C'u16, 0xDFF3'u16, 0xFE0F'u16, 0x26A7'u16], UTFEndianness.Host)
echo view.codepointLen
echo view.toUtf8
