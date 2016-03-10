local redis = require "resty.redis"
local red = redis:new()

local config = require("lua.appConfig")

red:set_timeout(1000) -- 1 sec

-- or connect to a unix domain socket file listened
-- by a redis server:
--     local ok, err = red:connect("unix:/path/to/redis.sock")

local ok, err = red:connect(config["redis_host"], config["redis_port"])
if not ok then
   -- ngx.say("failed to connect: ", err)
	returnResult["errorCode"] = "01"
	returnResult["errorMessage"] = "failed to connect: " .. err
   ngx.say(cjson.encode(returnResult))
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


local returnResult = {errorCode="00", errorMessage="", returnObject=""}

-- parameter checking

if not args.activityCode then
   returnResult["errorCode"] = "01"
   returnResult["errorMessage"] = "No activityCode parameter."
   ngx.say(cjson.encode(returnResult))
   return
end

-- end of parameter checking

local res, err

res, err = red:lrange(args.activityCode .. "_reservations", 0, -1)

if res == ngx.null then
   returnResult["errorCode"] = "02"
   returnResult["errorMessage"] = "Can't find reservations."
   ngx.say(cjson.encode(returnResult))
   return
end

for i,value in ipairs(res) do
	local reservations = cjson.decode(value)
	
	ngx.say("i = ", i, " #reservations = ", #reservations, " reservations.trackingId=", reservations.trackingId)
	
	if reservations.trackingId then
		local reservation
		reservation, err = red:get(args.activityCode .. "_reservation_" .. reservations.trackingId)
	
		-- if can't find the reservation, it means it has been expired, and will be removed
		if reservation == ngx.null then
			ngx.say("remove because of expired")
			res, err = red:lrem(args.activityCode .. "_reservations", 0, value)
			
			-- return back the available quantities of resources in this reservation
			for rKey, rValue in pairs(reservations) do
				-- only handle the resources' data except the 'trackingId'
				ngx.say("rKey=", rKey, "rValue=", rValue)
				if (rKey == "trackingId") then
				else
					red:incrby(args.activityCode .. "_resource_" .. rKey, rValue)
				end
			end
		else
			-- do nothing
		end
	else
		ngx.say("remove because of no trackingId")
		res, err = red:lrem(args.activityCode .. "_reservations", 0, value)
	end
end

ngx.say(cjson.encode(returnResult))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
   -- ngx.say("failed to set keepalive: ", err)
	returnResult["errorCode"] = "03"
	returnResult["errorMessage"] = "failed to set keepalive: " .. err
   return
end

