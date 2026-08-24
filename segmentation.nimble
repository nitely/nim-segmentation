# Package

version = "0.2.0"
author = "Esteban Castro Borsani (@nitely)"
description = "Unicode text segmentation tr29"
license = "MIT"
srcDir = "src"
skipDirs = @["tests", "gen"]

requires "nim >= 1.6.20"
requires "unicodedb >= 0.14.1"

task test, "Test":
  exec "nim c -r src/segmentation.nim"
  exec "nim c -r tests/tests.nim"

  # Test runnable examples
  #exec "nim doc -o:./docs/ugh/ugh.html ./src/segmentation.nim"

task docs, "Docs":
  exec "nim doc -o:./docs/index.html ./src/segmentation.nim"
