local redis = require "resty.redis"
local utils = (require "lua.lib.utils"):new()

local red = redis:new()

local config = require("lua.appConfig")

red:set_timeout(1000) -- 1 sec

local ok, err = red:connect(config["redis_host"], config["redis_port"])
if not ok then
   ngx.say(cjson.encode(utils:getReturnResult("01","Failed to connect: " .. err )))
   return
end

local cjson = require "cjson.safe"

local args

if (ngx.var.request_method == "POST") then
	ngx.req.read_body()
   args = ngx.req.get_post_args()
else
   args = ngx.req.get_uri_args()
end

-- parameter checking

if not args.activityCode then
	ngx.say(cjson.encode(utils:getReturnResult("02","No activityCode parameter.")))
   return
end

-- end of parameter checking

local res, err

res, err = red:lrange(args.activityCode .. "_reservations", 0, -1)

ngx.say("res=" .. tostring(res))

if res == ngx.null then
	ngx.say(cjson.encode(utils:getReturnResult("03","Can't find reservations.")))
   return
end

for i,value in ipairs(res) do
	local reservations = cjson.decode(value)
	
	if reservations.trackingId then
		local reservation
		reservation, err = red:get(args.activityCode .. "_reservation_" .. reservations.trackingId)
	
		-- if can't find the reservation, it means it has been expired, and will be removed
		if reservation == ngx.null then
			res, err = red:lrem(args.activityCode .. "_reservations", 0, value)
			
			-- return back the available quantities of resources in this reservation
			for rKey, rValue in pairs(reservations) do
				-- only handle the resources' data except the 'trackingId'
				if (rKey == "trackingId") then
				else
					red:incrby(args.activityCode .. "_resource_" .. rKey, rValue)
				end
			end
		else
			-- do nothing
		end
	else
		res, err = red:lrem(args.activityCode .. "_reservations", 0, value)
	end
end

ngx.say(cjson.encode(utils:getReturnResult("00")))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
	ngx.say(cjson.encode(utils:getReturnResult("06","Failed to set keepalive: " .. err)))
   return
end
