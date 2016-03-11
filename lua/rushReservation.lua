local redis = require "resty.redis"
local red = redis:new()

local config = require("lua.appConfig")

local uuid = require("lua.lib.resty.uuid")

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

if not args.reservationData then
   returnResult["errorCode"] = "02"
   returnResult["errorMessage"] = "No reservationData parameter."
   ngx.say(cjson.encode(returnResult))
   return
end

local jsonObject = cjson.decode(args.reservationData)

if not jsonObject then
   returnResult["errorCode"] = "03"
   returnResult["errorMessage"] = "parameter reservationData is not valid JSON format."
   ngx.say(cjson.encode(returnResult))
   return
end

-- end of parameter checking

local res, err

-- check if can do this operation
local httpt = require "lua.lib.resty.http"
local httpc = httpt.new()

res, err = httpc:request_uri(config["get_rush_activity_status_api_url"] .. "?activityCode=" .. args.activityCode, {
   method = "GET"
})

ngx.log(ngx.ERR, "called getRushActivityStatus, and return: ", res.body)

local returnData = cjson.decode(res.body)

if (returnData.errorCode == "00" and returnData.returnObject == "RUNNING") then
else
	returnResult["errorCode"] = "06"
	returnResult["errorMessage"] = "The activity's status is not RUNNING."
	ngx.say(cjson.encode(returnResult))
	return
end

-- end of checking

local reservations = {}
local hasSuccessfulReservations = false

for i,value in ipairs(jsonObject) do
	res, err = red:get(args.activityCode .. "_resource_" .. value.resourceCode)

	if not res then
		returnResult["errorCode"] = "04"
		if not err then
			returnResult["errorMessage"] = "Some errors occured when operating Redis!"
		else
			returnResult["errorMessage"] = "Some errors occured when operating Redis : " .. err
		end
		ngx.say(cjson.encode(returnResult))
		return
	end
	
	if value.quantity < tonumber(res) then
		res, err = red:incrby(args.activityCode .. "_resource_" .. value.resourceCode, 0 - value.quantity)
		-- error handling
		reservations[value.resourceCode] = value.quantity
		
		hasSuccessfulReservations = true
	end
end

-- if has valid reservations, add to the reservation list, ready for storing into a database
if hasSuccessfulReservations then
	local trackingId = uuid()
	
	reservations.trackingId = trackingId
	
	local jsonReservations = cjson.encode(reservations)
	
	res, err = red:multi()

	res, err = red:rpush(args.activityCode .. "_reservations", jsonReservations)
	
	res, err = red:set(args.activityCode .. "_reservation_" .. trackingId, jsonReservations)
	
	-- expire after x seconds
	res, err = red:expire(args.activityCode .. "_reservation_" .. trackingId, config["reservation_expire_seconds"])
	
	res, err = red:exec()

	returnResult["errorCode"] = "00"
	returnResult["returnObject"] = reservations
else
	returnResult["errorCode"] = "05"
	returnResult["errorMessage"] = "can't reserve any resource."
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

