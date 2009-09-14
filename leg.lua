
(patt:p arrow action:e) 
      -> do
	   local parts = { p.text, " * (" }
	   local cbs = {}
           for _, name in ipairs(p.names) do
             cbs[#cbs+1] = "lpeg.Cb('" .. name .. "')"
           end
           parts[#parts+1] = table.concat(cbs, " * ")
	   parts[#parts+1] = ") / function ("
	   parts[#parts+1] = table.concat(names, ", ")
	   parts[#parts+1] = ") " .. e .. " end"
           return table.concat(parts)
         end

(namedpatt:p ':' name)
       -> do
            return "lpeg.Cg(" .. p.text
          end

leg = grammar ()
  token(t) = _ t _,
  not = token('!'),
  and = token('&'),
  lpar = token('('),
  rpar = token(')'),
  star = token('*'),
  plus = token('+'),
  opt = token('?'),
  bind = token(':'),
  equal = token('='),
  slash = token('/'),
  popen = token('?('),
  arrow = token('->'),
  marrow = token('=>'),
  do = token('do'),
  tend = token('end'),
  lbra = token('{'),
  rbra = token('}'),
  openg = token('grammar'),
  parms = lpar listof(name) rpar,

  ablock = do block tend / lbra tbody rbra,
  action = arrow ablock / marrow ablock,
  arg = rulename / fullpatt,
  args = lpar listof(arg) rpar,
  ruleapp = rulename args?,
  prefixpatt = lpar fullpatt rpar / not prefixpatt / and prefixpatt / string / ruleapp,
  simplepatt = prefixpatt (star / plus / opt)?,
  namedpatt = simplepatt bind name
  actionpatt = (namedpatt / simplepatt / predicate)+ action,
  predicate = popen exp rpar,
  rule = name equal fullpatt,
  seqpatt = (actionpatt / simplepatt)+,
  fullpatt = seqpatt (slash seqpatt)*,
  grammar = openg parms listof(rule) tend
end


p = (lpeg.Cg(lpeg.C(lpeg.P("foo")),"foo") * lpeg.Cg(lpeg.P"bar","bar") *
 lpeg.Cmt(lpeg.Cb"bar" * lpeg.Cb"foo", function (s, i, ...) print(...) return true end) * 
 ((lpeg.Cb"bar" * lpeg.Cb"foo") / function (...) print(...) return "x" end)) / function (...) print(...) end