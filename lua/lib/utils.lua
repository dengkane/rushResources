
local _M = {
    _VERSION = '0.06',
}

local mt = { __index = _M }


function _M.new(self)
    return setmetatable({ }, mt)
end


function _M.eval(self, expr)
   local f = load('return ' .. expr)
   return f()
end

function _M.getReturnResult(self, errorCode, errorMessage, returnObject)
	local returnResult = { errorCode = errorCode }
	if errorMessage then
		returnResult["errorMessage"] = errorMessage
	end

	if returnObject then
		returnResult["returnObject"] = returnObject
	end

	return returnResult
end

function _M.handleRedisReturns(self, res, err, errorCode)
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

return _M

