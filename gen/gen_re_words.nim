import strutils

const
  unicodeVersion* = "12.1.0"
  specVersion* = "29"
  specURL* = "http://www.unicode.org/reports/tr29/"

# Rules without "Ignore Format and Extend characters"
#[
  (
    CR LF
    | Newline | CR | LF
    | ZWJ Extended_Pictographic
    | WSegSpace+
    | AHLetter+
    | AHLetter ((MidLetter | MidNumLetQ) AHLetter)+
    | Hebrew_Letter Single_Quote
    | Hebrew_Letter (Double_Quote Hebrew_Letter)+
    | Numeric+
    | (AHLetter Numeric)+
    | (Numeric AHLetter)+
    | Numeric ((MidNum | MidNumLetQ) Numeric)+
    | Katakana+
    | ((AHLetter | Numeric | Katakana | ExtendNumLet) ExtendNumLet)+
    | (RI RI)+
    | Other
  )

  The following rule handles: AHLetter+, Numeric+, (AHLetter | Numeric)+,
  and merge of rules (AHLetter ((MidLetter | MidNumLetQ) AHLetter)+)
  and (Numeric ((MidNum | MidNumLetQ) Numeric)+),
  also (Hebrew_Letter Single_Quote Hebrew_Letter)+

  (
    AHLetter ((MidLetter | MidNumLetQ) AHLetter)*
    | Numeric ((MidNum | MidNumLetQ) Numeric)*
  )+
]#

# Handmade regex based on the word-break table in the spec
# Apparently anything can be before "ZWJ EMOJI", albeit the spec does
# not mention it
# Reference (X: (Extend | Format | ZWJ)*)
const pattern =
  """
  (
    CR LF
    | Newline | CR | LF
    | (
      ZWJ Extended_Pictographic
      | WSegSpace+
      | (
          AHLetter X ((MidLetter | MidNumLetQ) X AHLetter X)*
          | Numeric X ((MidNum | MidNumLetQ) X Numeric X)*
          | ExtendNumLet X (Katakana+ X ExtendNumLet X)*
        )+
      | Hebrew_Letter X Single_Quote
      | Hebrew_Letter X (Double_Quote X Hebrew_Letter X)+
      | ((Katakana | ExtendNumLet) X)+
      | RegionalIndicator X RegionalIndicator
      | Other
    ) X (ZWJ Extended_Pictographic X)*
  )
  """

# IDs must be in non-overlapping substring order (i.e longest to shortest)
const identifiers = [
  "__EOF__",  # Reserved for the DFA
  "Extended_Pictographic",
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

const anyOther = [
  "Extended_Pictographic",
  "RegionalIndicator",
  "Hebrew_Letter",
  "Single_Quote",
  "Double_Quote",
  "ExtendNumLet",
  "MidNumLet",
  "WSegSpace",
  "MidLetter",
  "Katakana",
  "ALetter",
  "Numeric",
  #"Newline",
  "Extend",
  "Format",
  "MidNum",
  "Other",
  "ZWJ",
  #"CR",
  #"LF"
]

var letters = ""
for c in 'a' .. 'z':
  letters.add(c)

proc buildRePattern(p: string): string =
  assert len(identifiers) <= len(letters)
  result = p
  result = replace(result, "Other", "(" & anyOther.join(" | ") & ")")
  result = replace(result, "AHLetter", "(ALetter | Hebrew_Letter)")
  result = replace(result, "MidNumLetQ", "(MidNumLet | Single_Quote)")
  result = replace(result, "X", "(Extend | Format | ZWJ)*")
  result = replace(result, "(", "(?:")
  for i, id in identifiers:
    result = replace(result, id, "" & letters[i])
  result = replace(result, " ")
  result = replace(result, "\p")
  result = replace(result, "\n")

when isMainModule:
  echo "pattern:"
  echo buildRePattern(pattern)
