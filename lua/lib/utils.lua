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
         returnResult = self:getReturnResult(errorCode,"Some errors occured when operating Redis!")
      else
         returnResult = self:getReturnResult(errorCode,"Some errors occured when operating Redis : " .. err)
      end
      return
   end
	return returnResult
end

return utils

