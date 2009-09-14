
require "lpeg"

--[[

Implements the following grammar (meta_g) with higher-order productions

S <- <listof num>
num <- [0-9]+
listof r <- <r> ',' <listof r> / <r>

meta_g is the "uncooked" grammar, obtained by "compiling" the above leg grammar
fix takes an "uncooked" grammar and an initial symbol and cooks it, returning a parser

]]

-- function to synthesize rule names
function make_name(g, name, ...)
  local names = { tostring(g), name }
  for arg in ipairs{ ... } do names[#names+1] = tostring(arg) end
  return table.concat(names, "_")
end

local meta_g = { }

-- listof grammar rule
function meta_g:listof(fix, r)
  local name = make_name(self, "listof", r)
  if not fix[name] then 
    fix[name] = true
    fix[name] = r(self, fix) * "," * self:listof(fix, r) + r(self, fix)
  end
  return lpeg.V(name)
end

-- num grammar rule
function meta_g:num(fix)
  local name = make_name(self, "num")
  if not fix[name] then 
    fix[name] = true
    fix[name] = lpeg.R('09')^1
  end
  return lpeg.V(name)
end

-- S grammar rule
function meta_g:S(fix)
  local name = make_name(self, "S")
  if not fix[name] then
    fix[name] = true
    fix[name] = self:listof(fix, self.num)
  end
  return lpeg.V(name)
end

function fix_meta(g, s)
  local fix_t = {}
  fix_t[1] = g[s](g,fix_t)
  return lpeg.P(fix_t)
end

local patt = fix_meta(meta_g, "S")
lpeg.print(patt)

print(patt:match("12,34,323"))
