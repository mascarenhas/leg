-- $Id: re.lua,v 1.32 2008/10/09 20:25:06 roberto Exp $

require"lpeg"

module("leg", package.seeall)

local any = lpeg.P(1)

local function getdef (st, name, args)
   local alist = table.concat(args, ", ")
   if alist ~= "" then alist = ", " .. alist end
   if not st.params[name] then
     return "self[" .. string.format("%q", name) .. "](self, fix " .. alist .. ")" 
   else
     return name .. "(self, fix " .. alist .. ")" 
   end
end

local function patt_error (s, i)
  local msg = (#s < i + 20) and s:sub(i)
                             or s:sub(i,i+20) .. "..."
  msg = ("pattern error near '%s'"):format(msg)
  error(msg, 2)
end

local function mult (p, n)
  local np = "lpeg.P(true)"
  while n >= 1 do
    if n%2 >= 1 then np = np .. " * " .. p end
    p = p .. " * " .. p
    n = n/2
  end
  return np
end

local S = (lpeg.S(" \t\n") + "--" * (any - lpeg.S"\n")^0)^0

local s = lpeg.P" "^1

local name = lpeg.R("AZ", "az") * lpeg.R("AZ", "az", "09")^0

local exp_follow = lpeg.P"/" + ")" + "}" + ":}" + "~}" + ">" + name + -1

name = lpeg.C(name)

-- identifiers only have meaning in a given environment
local Identifier = name * lpeg.Carg(1)

local Defname = lpeg.Carg(1) * name * lpeg.Ct((s * name)^0)

local arg_name = name * lpeg.Carg(1) /
  function (name, st)
    if not st.params[name] then
      return "self[" .. string.format("%q", name) .. "]"
    else
      return name
    end
  end

local arg_exp = lpeg.V"Exp" * lpeg.Carg(1) /
  function (exp, st)
    return "function (" .. table.concat(st.params, ", ") .. ")\n return " .. exp .. "\nend"
  end

local Call = lpeg.Carg(1) * name * lpeg.Ct((s * (arg_name + arg_exp))^0) 

local num = lpeg.C(lpeg.R"09"^1) * S / tonumber

local String = "'" * lpeg.C((any - "'")^0) * "'" +
               '"' * lpeg.C((any - '"')^0) * '"'

local Cat = "%" * Identifier / function (c,Defs)
  return "self[" .. string.format("%q", c) .. "](self, fix)"
end

local Range = lpeg.Cs(any * (lpeg.P"-"/"") * (any - "]")) / function (term) return "lpeg.R(" .. string.format("%q", term) .. ")" end

local item = Cat + Range + lpeg.C(any) / function (term) return "lpeg.P(" .. string.format("%q", term) .. ")" end

local Class =
    "["
  * (lpeg.C(lpeg.P"^"^-1))    -- optional complement symbol
  * lpeg.Cf(item * (item - "]")^0, function (acc, term) return acc .. " + " .. term end) /
                function (c, p) return c == "^" and "lpeg.P(1) - (" .. p .. ")" or p end
  * "]"

local function addparms(s, i, st, name, params)
  st.params = {}
  for i, p in ipairs(params) do
    st.params[p] = true
    st.params[i] = p
  end
  return i, st, name, params
end

local function adddef (acc, st, name, params, exp)
  local plist = table.concat(params, ", ")
  if plist ~= "" then plist = ", " .. plist end
  local fun = [[
meta_g[]] .. string.format("%q", name) .. [[] = function (self, fix]] .. plist .. [[)
  local name = make_name(self, ]] .. string.format("%q", name) .. plist .. [[)
  if not fix[name] then 
    fix[name] = true
    fix[name] = ]] .. exp .. [[
  end
  return lpeg.V(name)
end
]]
  return acc .. fun
end

local function firstdef (st, name, params, exp) return adddef([[
local function equalcap (s, i, c)
  if type(c) ~= "string" then return nil end
  local e = #c + i
  if s:sub(i, e - 1) == c then return e else return nil end
end

local function make_name(g, name, ...)
  local names = { tostring(g), name }
  for arg in ipairs{ ... } do names[#names+1] = tostring(arg) end
  return table.concat(names, "_")
end

local meta_g = { }
]], st, name, params, exp) end

local grammar = lpeg.P{ "Grammar",
  Exp = S * lpeg.Cf(lpeg.V"Seq" * ("/" * S * lpeg.V"Seq")^0, function (acc, term) return acc .. " + " .. term end ) /
              function (term) return "(" .. term .. ")" end;
  Seq = lpeg.Cf(lpeg.Cc("lpeg.P''") * lpeg.V"Prefix"^0 , function (acc, term) return acc .. " * " .. term end)
        * (#exp_follow + patt_error);
     Prefix = "&" * S * lpeg.V"Prefix" / function (term) return "#(" .. term .. ")" end
         + "!" * S * lpeg.V"Prefix" / function (term) return "-(" .. term .. ")" end
         + lpeg.V"Suffix";
  Suffix = lpeg.Cf(lpeg.V"Primary" * S *
	  ( ( lpeg.P"+" * lpeg.Cc(1, function (term, exp) return "(" .. term .. ")^".. exp end)
	    + lpeg.P"*" * lpeg.Cc(0, function (term, exp) return "(" .. term .. ")^".. exp end)
	    + lpeg.P"?" * lpeg.Cc(-1, function (term, exp) return "(" .. term .. ")^".. exp end)
            + "^" * ( lpeg.Cg(num * lpeg.Cc(mult))
		   + lpeg.Cg(lpeg.C(lpeg.S"+-" * lpeg.R"09"^1) * lpeg.Cc(function (term, exp) return "(" .. term .. ")^".. exp end))
                    )
	    + "->" * S * ( lpeg.Cg(String * lpeg.Cc(function (term, func) return term .. " / ".. string.format("%q", func) end))
			 + lpeg.P"{}" * lpeg.Cc(nil, function (term) return "lpeg.Ct(" .. term .. ")" end)
                         + lpeg.Cg(name * lpeg.Cc(function (term, func) return term .. " / ".. func end))
                         )
	    + "=>" * S * lpeg.Cg(name * lpeg.Cc(function (term, func) return "lpeg.Cmt(" .. term .. ", ".. func .. ")" end))
            ) * S
          )^0, function (a,b,f) return f(a,b) end );
  Primary = "(" * lpeg.V"Exp" * ")"
            + String / function (term) return "lpeg.P(" .. string.format("%q", term) .. ")" end
            + Class
            + Cat
            + "{:" * (name * ":" + lpeg.Cc(nil)) * lpeg.V"Exp" * ":}" /
    	             function (n, p) return "lpeg.Cg(" .. p .. "," .. string.format("%q", n) .. ")" end
  	    + "=" * name / function (n) return "lpeg.Cmt(lpeg.Cb(" .. string.format("%q", n) .. "), equalcap)" end
	    + lpeg.P"{}" / function () return "lpeg.Cp()" end
	    + "{~" * lpeg.V"Exp" * "~}" / function (term) return "lpeg.Cs(" .. term .. ")" end
            + "{" * lpeg.V"Exp" * "}" / function (term) return "lpeg.C(" .. term .. ")" end
	    + lpeg.P"." * lpeg.Cc("lpeg.P(1)")
	    + "<" * Call * ">" / getdef;
  Definition = lpeg.Cmt(Defname, addparms) * S * '<-' * lpeg.V"Exp";
  Grammar = lpeg.Cf(lpeg.V"Definition" / firstdef * lpeg.Cg(lpeg.V"Definition")^0, adddef) /
             function (g) return g .. "\n\nreturn meta_g" end
}

local grammar = S * grammar * (-lpeg.P(1) + patt_error)

function compile (p)
  if type(p) == "function" then return p end
  local cp = grammar:match(p, 1, { params = {} })
  if not cp then error("incorrect pattern", 3) end
  local fun, err = loadstring(cp)
  if fun then return fun, cp else return cp, err end
end

function fix(g, s)
  local fix_t = {}
  fix_t[1] = g[s](g,fix_t)
  return lpeg.P(fix_t)
end
