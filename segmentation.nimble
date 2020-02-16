# Package

version = "0.1.0"
author = "Esteban Castro Borsani (@nitely)"
description = "Unicode text segmentation tr29"
license = "MIT"
srcDir = "src"
skipDirs = @["tests", "gen"]

requires "nim >= 0.19.0"
requires "unicodedb >= 0.8.0"

task test, "Test":
  exec "nim c -r src/segmentation.nim"
  exec "nim c -r tests/tests.nim"

  # Test runnable examples
  #exec "nim doc -o:./docs/ugh/ugh.html ./src/segmentation.nim"

task docs, "Docs":
  exec "nim doc -o:./docs/index.html ./src/segmentation.nim"
