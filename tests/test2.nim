import ferrite/utf8view

var view = newUTF8View("Hello there!")
let (valid, count) = view.validate()

echo valid
echo count
echo view.len
