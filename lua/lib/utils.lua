local utils = { }

function utils.eval(expr)
   local f = load('return ' .. expr)
   return f()
end

function utils.getReturnResult(errorCode, errorMessage, returnObject)
	local returnResult = { errorCode = errorCode }
	if errorMessage then
		returnResult["errorMessage"] = errorMessage
	end

	if returnObject then
		returnResult["returnObject"] = returnObject
	end

	return returnResult
end

function utils.handleRedisReturns(res, err, errorCode)
	local returnResult

   if not res then
      if not err then
         returnResult = utils.getReturnResult(errorCode,"Some errors occured when operating Redis!")
      else
         returnResult = utils.getReturnResult(errorCode,"Some errors occured when operating Redis : " .. err)
      end
      return
   end
	return returnResult
end

function utils.decodeURI(s)
   s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
   return s
end

function utils.encodeURI(s)
   s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
   return string.gsub(s, " ", "+")
end

function utils.loadstring(functionScript)
   local f, err = loadstring("return function (arg) " .. functionScript .. " end", functionScript)
   if f then return f() else return f, err end
end

return utils

