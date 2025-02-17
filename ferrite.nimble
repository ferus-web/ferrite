# Package

version = "0.1.3"
author = "xTrayambak"
description = "A collection of utilities that are useful for implementing web standards"
license = "MIT"
srcDir = "src"
backend = "cpp"

# Dependencies

requires "nim >= 2.2.0"
requires "results >= 0.5.1"

task fmt, "Format code":
  exec "nph src/ tests/"

requires "simdutf >= 6.1.1"
