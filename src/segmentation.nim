## This library implements Unicode Text Segmentation (tr29)

import macros
import unicode

import unicodedb/segmentation

# Not every state can exit, so this needs backtracking
# See ../gen/gen_re_words.nim for the original regex
const wordBreakTable = [
  [-1'i8, 1, 2, 3, 4, 2, 2, 5, 2, 6, 2, 7, 1, 8, 9, 2, 2, 2, 2, 10, 11, 9],
  [0'i8, 1, -1, -1, 1, 12, -1, 13, 12, -1, 12, -1, 1, 8, -1, 1, 1, -1, -1, 14, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2, 2, -1, -1, 10, -1, -1],
  [0'i8, -1, -1, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 3, -1, -1, 15, -1, -1],
  [0'i8, 1, -1, -1, 1, 16, 17, 13, 12, -1, 12, -1, 1, 8, -1, 4, 4, -1, -1, 18, -1, -1],
  [0'i8, 1, -1, -1, 1, -1, -1, 5, -1, -1, -1, 19, 1, 8, -1, 5, 5, -1, -1, 20, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, -1, -1, 6, -1, -1, -1, -1, -1, 2, 2, -1, -1, 10, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, 7, -1, -1, -1, 7, -1, -1, -1, 7, 7, -1, -1, 21, -1, -1],
  [0'i8, 1, -1, -1, 1, 22, -1, 13, 22, -1, -1, -1, 1, 8, -1, 8, 8, 22, -1, 23, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
  [0'i8, 1, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2, 2, -1, -1, 10, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 9],
  [-1'i8, 1, -1, -1, 1, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, 12, 12, -1, -1, 12, -1, -1],
  [0'i8, 1, -1, -1, 1, -1, -1, 13, -1, -1, -1, 24, 1, 8, -1, 13, 13, -1, -1, 25, -1, -1],
  [0'i8, 1, 2, -1, 1, 12, -1, 13, 12, -1, 12, -1, 1, 8, -1, 1, 1, -1, -1, 14, -1, -1],
  [0'i8, 1, 2, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, 3, -1, -1, 15, -1, -1],
  [0'i8, 1, -1, -1, 1, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, 16, 16, -1, -1, 26, -1, -1],
  [-1'i8, -1, -1, -1, 27, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 17, 17, -1, -1, 17, -1, -1],
  [0'i8, 1, 2, -1, 1, 16, 17, 13, 12, -1, 12, -1, 1, 8, -1, 4, 4, -1, -1, 18, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, 5, -1, -1, -1, 19, -1, -1, -1, 28, 28, -1, -1, 29, -1, -1],
  [0'i8, 1, 2, -1, 1, -1, -1, 5, -1, -1, -1, 19, 1, 8, -1, 5, 5, -1, -1, 20, -1, -1],
  [0'i8, 1, 2, -1, -1, -1, -1, 7, -1, -1, -1, 7, -1, -1, -1, 7, 7, -1, -1, 21, -1, -1],
  [-1'i8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 8, -1, 22, 22, -1, -1, 22, -1, -1],
  [0'i8, 1, 2, -1, 1, 22, -1, 13, 22, -1, -1, -1, 1, 8, -1, 8, 8, 22, -1, 23, -1, -1],
  [-1'i8, -1, -1, -1, -1, -1, -1, 13, -1, -1, -1, 24, -1, -1, -1, 30, 30, -1, -1, 30, -1, -1],
  [0'i8, 1, 2, -1, 1, -1, -1, 13, -1, -1, -1, 24, 1, 8, -1, 13, 13, -1, -1, 25, -1, -1],
  [0'i8, 1, 2, -1, 1, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, 16, 16, -1, -1, 26, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, -1, 27, 27, -1, -1, 31, -1, -1],
  [0'i8, -1, -1, -1, -1, -1, -1, 5, -1, -1, -1, 7, -1, -1, -1, 28, 28, -1, -1, 29, -1, -1],
  [0'i8, 1, 2, -1, -1, -1, -1, 5, -1, -1, -1, 7, -1, -1, -1, 28, 28, -1, -1, 29, -1, -1],
  [-1'i8, -1, -1, -1, -1, -1, -1, 13, -1, -1, -1, -1, -1, -1, -1, 30, 30, -1, -1, 30, -1, -1],
  [0'i8, 1, 2, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, -1, 27, 27, -1, -1, 31, -1, -1]]

func genWordBreakMap(prop: NimNode): NimNode =
  ## Gen mapping from word-break prop to DFA column
  # from gen/gen_re_words.nim
  const idnts = [
    "__EOF__",  # Reserved for the DFA
    "ALetterExtendedPictographic",  # ALetter & Extended_Pictographic
    "Extended_Pictographic",
    #"ExtPict",
    "RegionalIndicator",
    "Hebrew_Letter",
    "Single_Quote",
    "Double_Quote",
    "ExtendNumLet",
    "MidNumLet",
    #"MidNumLetQ",
    "WSegSpace",
    "MidLetter",
    "Katakana",
    "ALetter",
    #"AHLetter",
    "Numeric",
    "Newline",
    "Extend",
    "Format",
    "MidNum",
    "Other",
    "ZWJ",
    "CR",
    "LF"
  ]
  var caseStmt: seq[NimNode]
  caseStmt.add(prop)
  for i in 1 .. idnts.len-1:
    caseStmt.add(newTree(nnkOfBranch,
      ident("sgw" & idnts[i]),
      newLit i))
  let falseLit = newLit false
  let badResultLit = newLit -1
  caseStmt.add(newTree(nnkElse,
    quote do:
      doAssert `falseLit`
      `badResultLit`))
  result = newStmtList(
    newTree(nnkCaseStmt, caseStmt))

macro genWordBreakMap(prop: SgWord): untyped =
  result = genWordBreakMap(prop)
  when defined(reDumpWrodBreak):
    echo "==== genWordBreakMap ===="
    echo repr(result)

# XXX wordBounds (not words)
iterator wordsBounds*(s: string): Slice[int] {.inline.} =
  ## Return each word boundary in `s`. Boundaries are inclusive
  var
    state, a, b, c = 0
    r: Rune
  while b < s.len:
    state = 0
    while true:
      fastRuneAt(s, b, r, true)
      let prop = genWordBreakMap(wordBreakProp(r))
      let next = wordBreakTable[state][prop]
      if next == -1:
        doAssert state > 0
        b = c
        break
      # save point
      if wordBreakTable[next][0] == 0:
        c = b
      if b >= s.len:
        b = c
        break
      state = next
    doAssert b > a
    yield a .. b-1
    a = b

iterator words*(s: string): string {.inline.} =
  ## Return each word in `s`
  for b in s.wordsBounds:
    yield s[b]

when isMainModule:
  block:
    echo "Test genWordBreakMap"
    var i = 0
    for cp in 0 .. 0x10FFFF:
      doAssert genWordBreakMap(wordBreakProp(Rune(cp))) >= 0
      inc i
    doAssert i == 0x10FFFF+1
