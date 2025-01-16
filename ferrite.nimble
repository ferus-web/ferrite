# Package

version       = "0.1.0"
author        = "xTrayambak"
description   = "A collection of utilities that are useful for implementing web standards"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.0"
requires "results >= 0.5.1"

task fmt, "Format code":
  exec "nph src/ tests/"
