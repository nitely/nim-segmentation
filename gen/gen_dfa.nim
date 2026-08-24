## Regex to DFA table generator
##
## It takes the regex built by gen_re_words.nim, builds a DFA
## (powerset construction), minimizes it (Moore's algorithm) and
## returns the transitions table used by src/segmentation.nim
##
## The supported syntax is the one gen_re_words.nim generates:
## literals ('a' .. 'z'), "(?:...)", "|", "*", "+" and "?"
##
## The table has one row per state (row 0 is the start state) and one
## column per gen_re_words.identifiers entry. Column 0 is the reserved
## __EOF__ column: 0 when the state is a match, -1 otherwise. Every
## other cell is the next state, or -1 when there is no transition
##
## See gen_re_words.nim for the usage; `nim c -r gen/gen_dfa.nim`
## runs this module's own tests

import std/[strutils, tables, sets, hashes]

# Parser

type
  NodeKind = enum
    nkChar, nkCat, nkAlt, nkStar, nkPlus, nkOpt
  Node = ref object
    kind: NodeKind
    c: char
    children: seq[Node]
  Parser = object
    s: string
    i: int

proc parseAlt(p: var Parser): Node

proc parseAtom(p: var Parser): Node =
  if p.s.continuesWith("(?:", p.i):
    p.i += 3
    result = parseAlt(p)
    doAssert p.i < p.s.len and p.s[p.i] == ')', "unbalanced parenthesis"
    inc p.i
  else:
    doAssert p.s[p.i] in {'a' .. 'z'},
      "unsupported regex syntax: " & p.s[p.i]
    result = Node(kind: nkChar, c: p.s[p.i])
    inc p.i

proc parseRep(p: var Parser): Node =
  result = parseAtom(p)
  while p.i < p.s.len and p.s[p.i] in {'*', '+', '?'}:
    let kind = case p.s[p.i]
      of '*': nkStar
      of '+': nkPlus
      else: nkOpt
    result = Node(kind: kind, children: @[result])
    inc p.i

proc parseCat(p: var Parser): Node =
  var nodes: seq[Node]
  while p.i < p.s.len and p.s[p.i] notin {'|', ')'}:
    nodes.add parseRep(p)
  doAssert nodes.len > 0, "empty expression"
  result = if nodes.len == 1: nodes[0]
    else: Node(kind: nkCat, children: nodes)

proc parseAlt(p: var Parser): Node =
  var nodes = @[parseCat(p)]
  while p.i < p.s.len and p.s[p.i] == '|':
    inc p.i
    nodes.add parseCat(p)
  result = if nodes.len == 1: nodes[0]
    else: Node(kind: nkAlt, children: nodes)

proc parse(re: string): Node =
  var p = Parser(s: re, i: 0)
  result = parseAlt(p)
  doAssert p.i == re.len, "unbalanced parenthesis"

# Thompson's NFA

type
  NfaState = object
    eps: seq[int]
    trans: seq[tuple[c: char, to: int]]
  Nfa = object
    states: seq[NfaState]

proc newState(n: var Nfa): int =
  n.states.add NfaState()
  result = n.states.len-1

proc build(n: var Nfa, node: Node): tuple[start, final: int] =
  case node.kind
  of nkChar:
    let start = n.newState
    let final = n.newState
    n.states[start].trans.add (node.c, final)
    result = (start, final)
  of nkCat:
    result = n.build(node.children[0])
    for i in 1 .. node.children.high:
      let next = n.build(node.children[i])
      n.states[result.final].eps.add next.start
      result.final = next.final
  of nkAlt:
    let start = n.newState
    let final = n.newState
    for child in node.children:
      let sub = n.build(child)
      n.states[start].eps.add sub.start
      n.states[sub.final].eps.add final
    result = (start, final)
  of nkStar, nkPlus, nkOpt:
    let start = n.newState
    let final = n.newState
    let sub = n.build(node.children[0])
    n.states[start].eps.add sub.start
    n.states[sub.final].eps.add final
    if node.kind != nkOpt:  # repeat
      n.states[sub.final].eps.add sub.start
    if node.kind != nkPlus:  # skip
      n.states[start].eps.add final
    result = (start, final)

proc epsClosure(n: Nfa, states: HashSet[int]): HashSet[int] =
  result = states
  var stack: seq[int]
  for s in states:
    stack.add s
  while stack.len > 0:
    let s = stack.pop
    for e in n.states[s].eps:
      if e notin result:
        result.incl e
        stack.add e

proc key(n: Nfa, states: HashSet[int]): seq[int] =
  ## An ordered (i.e hashable) view of a set of NFA states
  for s in 0 .. n.states.high:
    if s in states:
      result.add s

# DFA

type
  Dfa* = object
    alphabet*: string
    trans*: seq[seq[int]]  ## trans[state][alphabet index], -1 is no transition
    accepting*: seq[bool]

proc powerset(n: Nfa, start, final: int, alphabet: string): Dfa =
  result.alphabet = alphabet
  var
    ids = initTable[seq[int], int]()
    sets: seq[HashSet[int]]
  let s0 = n.epsClosure(toHashSet([start]))
  ids[n.key(s0)] = 0
  sets.add s0
  var i = 0
  while i < sets.len:
    let states = sets[i]
    inc i
    var row = newSeq[int](alphabet.len)
    for j in 0 .. row.high:
      row[j] = -1
    for j, c in alphabet:
      var move = initHashSet[int]()
      for s in states:
        for t in n.states[s].trans:
          if t.c == c:
            move.incl t.to
      if move.len == 0:
        continue
      let closure = n.epsClosure(move)
      let k = n.key(closure)
      if k notin ids:
        ids[k] = sets.len
        sets.add closure
      row[j] = ids[k]
    result.trans.add row
    result.accepting.add final in states

proc minimize*(d: Dfa): Dfa =
  ## Moore's algorithm. States that cannot reach a match are dropped
  result.alphabet = d.alphabet
  let
    states = d.trans.len
    dead = states  # the implicit non-matching state
  proc dst(s, c: int): int =
    if s == dead: dead
    elif d.trans[s][c] == -1: dead
    else: d.trans[s][c]
  var
    part = newSeq[int](states+1)
    blocks = 1
  for s in 0 .. dead:
    if s < states and d.accepting[s]:
      part[s] = 1
      blocks = 2
  while true:
    var
      sigs = initTable[seq[int], int]()
      nextPart = newSeq[int](states+1)
    for s in 0 .. dead:
      var sig = @[part[s]]
      for c in 0 .. d.alphabet.high:
        sig.add part[dst(s, c)]
      if sig notin sigs:
        sigs[sig] = sigs.len
      nextPart[s] = sigs[sig]
    part = nextPart
    if sigs.len == blocks:  # no block was split
      break
    blocks = sigs.len
  var rep = initTable[int, int]()  # block -> state
  for s in 0 ..< states:
    if part[s] notin rep:
      rep[part[s]] = s
  let deadBlock = part[dead]
  doAssert part[0] != deadBlock, "the regex matches nothing"
  var
    ids = initTable[int, int]()  # block -> new state
    order: seq[int]
  proc newId(blk: int): int =
    if blk notin ids:
      ids[blk] = order.len
      order.add blk
    ids[blk]
  discard newId(part[0])  # the start state is always state 0
  var i = 0
  while i < order.len:
    let s = rep[order[i]]
    inc i
    var row = newSeq[int](d.alphabet.len)
    for c in 0 .. d.alphabet.high:
      let blk = part[dst(s, c)]
      row[c] = if blk == deadBlock: -1 else: newId(blk)
    result.trans.add row
    result.accepting.add d.accepting[s]
  # The matcher re-enters state 0 on every new word (see wordsBounds),
  # so it must not be reachable; give it a private copy when it is
  var reentered = false
  for row in result.trans:
    for t in row:
      reentered = reentered or t == 0
  if reentered:
    result.trans.add result.trans[0]
    result.accepting.add result.accepting[0]
    let copy = result.trans.high
    for row in result.trans.mitems:
      for t in row.mitems:
        if t == 0:
          t = copy

proc toDfa*(re, alphabet: string): Dfa =
  ## Build the minimal DFA matching `re`. Every char of `alphabet`
  ## is a table column, in order
  var n = Nfa()
  let (start, final) = n.build(parse(re))
  result = n.powerset(start, final, alphabet).minimize

proc longestMatch*(d: Dfa, s: string): int =
  ## Length of the longest prefix of `s` matching the DFA, or -1.
  ## This is what wordsBounds does for every word
  result = -1
  var state = 0
  for i in 0 .. s.high:
    let c = d.alphabet.find(s[i])
    doAssert c >= 0, "char is not in the alphabet: " & s[i]
    state = d.trans[state][c]
    if state == -1:
      break
    if d.accepting[state]:
      result = i+1

proc prettyTable*(d: Dfa): string =
  ## The table as a Nim array literal
  doAssert d.trans.len <= int8.high.int, "too many states for int8"
  var rows: seq[string]
  for s in 0 .. d.trans.high:
    doAssert d.trans[s][0] == -1, "column 0 is reserved for __EOF__"
    var cells = @[(if d.accepting[s]: "0'i8" else: "-1'i8")]
    for c in 1 .. d.alphabet.high:
      cells.add $d.trans[s][c]
    rows.add "  [" & cells.join(", ") & "]"
  result = rows.join(",\n") & "]"
  result = "const wordBreakTable = [\n" & result

when isMainModule:
  block tests:
    let d = toDfa("ab(?:c|d)*", "xabcd")
    doAssert d.longestMatch("ab") == 2
    doAssert d.longestMatch("abcdcd") == 6
    doAssert d.longestMatch("abcdx") == 4
    doAssert d.longestMatch("ax") == -1
    doAssert toDfa("a+", "xa").trans.len == 2
    # (?:a|b)*c and its unrolled form minimize to the same DFA
    doAssert toDfa("(?:a|b)*c", "xabc").trans ==
      toDfa("c|(?:a|b)(?:a|b)*c", "xabc").trans
    # state 0 is copied when it's reachable, i.e "a" and "aba" match,
    # but the DFA must not go back to the start state
    let e = toDfa("a(?:ba)*", "xab")
    doAssert e.longestMatch("a") == 1
    doAssert e.longestMatch("ababa") == 5
    doAssert e.longestMatch("abab") == 3
    for row in e.trans:
      for t in row:
        doAssert t != 0
  echo "ok"
