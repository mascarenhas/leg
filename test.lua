
require "leg"

fun, code = leg.compile[[
  grammar (foo)
    S <- <listof num>
    num <- {[0-9]+}
    listof r <- <r> ',' <listof r> / <r>
 end
]]

--print(code)

g = fun()

patt = leg.fix(g, "S")

print(patt:match"12,34,123")

fun = leg.compile[[
  grammar ()
    S <- <listof {[0-9]+}>
    listof r <- <r> ',' <listof r> / <r>
  end
]]

g = fun()

patt = leg.fix(g, "S")

print(patt:match"12,34,123")

listof = leg.compile[[
  grammar ()
    listof r <- <r> ',' <listof r> / <r>
  end
]]()

fun, code = leg.compile[[
  grammar (foo)
    S <- <foo.listof num>
    num <- {[0-9]+}
  end
]]

--print(code)

g = fun(nil, nil, listof)

patt = leg.fix(g, "S")

print(patt:match"12,34,123")

fun, code = leg.compile[[
  grammar (foo)
    S <- <foo.listof {[0-9]+}>
  end
]]

--print(code)

g = fun(nil, nil, listof)

patt = leg.fix(g, "S")

print(patt:match"12,34,123")
