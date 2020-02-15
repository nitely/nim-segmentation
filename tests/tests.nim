import unittest, strutils
import unicode except strip
import sequtils

import segmentation

proc wbreak(s: string): seq[string] =
  for ss in s.words:
    result.add ss

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
  doAssert wbreak("1,̈1.⁠") == @["1,̈1", ".⁠"]
  doAssert wbreak("\n̈‍") == @["\n", "̈‍"]  # 0xa 0x308 0x200d
  doAssert wbreak("〱A") == @["〱", "A"]
  doAssert wbreak("A_0_〱_") == @["A_0_〱_"]
  # ZWJ, checked at https://unicode.org/cldr/utility/breaks.jsp
  doAssert "🛑‍🛑".wbreak == @["🛑‍🛑"]
  doAssert "a🇦🇧🇨🇩b".wbreak == @["a", "🇦🇧", "🇨🇩", "b"]
  doAssert "a‍🛑".wbreak == @["a‍🛑"]
  doAssert "👶🏿̈‍👶🏿".wbreak == @["👶🏿̈‍👶🏿"]
  doAssert " ‍ن".wbreak == @[" ‍", "ن"]  # Space ZWJ letter
  doAssert "  ‍🛑".wbreak == @["  ‍🛑"]  # Space Space ZWJ Emoji

test "Test misc":
  doAssert wbreak("11 aa 22 bb 1.2 1,2 $1,2 $1") ==
    @["11", " ", "aa", " ", "22", " ", "bb", " ", "1.2", " ",
    "1,2", " ", "$", "1,2", " ", "$", "1"]
  doAssert wbreak("abc abc ghi can't") ==
    @["abc", " ", "abc", " ", "ghi", " ", "can\'t"]
  doAssert wbreak("The quick? (“brown”) fox can’t jump 32.3 feet, right?") ==
    @["The", " ", "quick", "?", " ", "(", "“", "brown", "”", ")",
    " ", "fox", " ", "can’t", " ", "jump", " ", "32.3", " ", "feet",
    ",", " ", "right", "?"]
  doAssert wbreak("3.2 3a 3.2a 3.2a3.2a a3.2 3. a3a a3.2a 1to1 1-1 1'1 1'a 1''1") ==
    @["3.2", " ", "3a", " ", "3.2a", " ", "3.2a3.2a", " ", "a3.2",
    " ", "3", ".", " ", "a3a", " ", "a3.2a", " ", "1to1", " ", "1",
    "-", "1", " ", "1'1", " ", "1", "'", "a", " ", "1", "'", "'", "1"]
  echo "The (“brown”) fox can’t jump 32.3 feet, right?".wbreak
