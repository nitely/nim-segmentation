import unittest, strutils
import unicode except strip
import sequtils

import segmentation

proc wbreak(s: string): seq[string] =
  toSeq(s.words)

test "Test words break":
  var i = 0
  for line in "./tests/WordBreakTest.txt".lines:
    var text = line.split('#', 1)[0]
    if text.strip.len == 0:
      continue
    var wordsFromTest: seq[string]
    for ch1 in text.split("÷"):
      if ch1.strip.len == 0:
        continue
      var words = ""
      for ch2 in ch1.split("×"):
        if ch2.strip.len == 0:
          continue
        words.add ch2.strip.parseHexInt.Rune.toUTF8
      wordsFromTest.add words
    check toSeq(wordsFromTest.join.words) == wordsFromTest
    inc i
  echo "$# words tested" % [$i]

test "Test some words":
  # From the txt file
  check wbreak("1,̈1.⁠") == @["1,̈1", ".⁠"]
  check wbreak("\n̈‍") == @["\n", "̈‍"]  # 0xa 0x308 0x200d
  check wbreak("〱A") == @["〱", "A"]
  check wbreak("A_0_〱_") == @["A_0_〱_"]
  # ZWJ, checked at https://unicode.org/cldr/utility/breaks.jsp
  check "🛑‍🛑".wbreak == @["🛑‍🛑"]
  check "a🇦🇧🇨🇩b".wbreak == @["a", "🇦🇧", "🇨🇩", "b"]
  check "a‍🛑".wbreak == @["a‍🛑"]
  check "👶🏿̈‍👶🏿".wbreak == @["👶🏿̈‍👶🏿"]
  check " ‍ن".wbreak == @[" ‍", "ن"]  # Space ZWJ letter
  check "  ‍🛑".wbreak == @["  ‍🛑"]  # Space Space ZWJ Emoji

test "Test misc":
  check wbreak("11 aa 22 bb 1.2 1,2 $1,2 $1") ==
    @["11", " ", "aa", " ", "22", " ", "bb", " ", "1.2", " ",
    "1,2", " ", "$", "1,2", " ", "$", "1"]
  check wbreak("abc abc ghi can't") ==
    @["abc", " ", "abc", " ", "ghi", " ", "can\'t"]
  check wbreak("The quick? (“brown”) fox can’t jump 32.3 feet, right?") ==
    @["The", " ", "quick", "?", " ", "(", "“", "brown", "”", ")",
    " ", "fox", " ", "can’t", " ", "jump", " ", "32.3", " ", "feet",
    ",", " ", "right", "?"]
  check wbreak("3.2 3a 3.2a 3.2a3.2a a3.2 3. a3a a3.2a 1to1 1-1 1'1 1'a 1''1") ==
    @["3.2", " ", "3a", " ", "3.2a", " ", "3.2a3.2a", " ", "a3.2",
    " ", "3", ".", " ", "a3a", " ", "a3.2a", " ", "1to1", " ", "1",
    "-", "1", " ", "1'1", " ", "1", "'", "a", " ", "1", "'", "'", "1"]

test "Test wordsBounds":
  check toSeq("abc def?".wordsBounds) ==
    @[0 .. 2, 3 .. 3, 4 .. 6, 7 .. 7]
