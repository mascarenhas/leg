
require "leg"

fun = leg.compile[[
  S <- <listof num>
  num <- {[0-9]+}
  listof r <- <r> ',' <listof r> / <r>
]]

g = fun()

patt = leg.fix(g, "S")

print(patt:match"12,34,123")

fun = leg.compile[[
  S <- <listof {[0-9]+}>
  listof r <- <r> ',' <listof r> / <r>
]]

g = fun()

patt = leg.fix(g, "S")

print(patt:match"12,34,123")
