local redis = require "resty.redis"
local red = redis:new()

local config = require("lua.appConfig")

local function clearExpiredReservations(premature, activityCode)
	if premature then
		return
	end
	
	ngx.log(ngx.ERR, "Running the job once ", activityCode)
	
   local httpt = require "resty.http"
   local httpc = httpt.new()
   
   local res, err = httpc:request_uri(config["clear_expired_reservations_api_url"] .. "?activityCode=" .. activityCode, {
      method = "GET"
   })
   
   ngx.log(ngx.ERR, "called clearExpiredReservations, return: ", res.body)
   
   res, err = httpc:request_uri(config["get_rush_activity_status_api_url"] .. "?activityCode=" .. activityCode, {
      method = "GET"
   })
   
   local cjson = require "cjson.safe"
   
   ngx.log(ngx.ERR, "called getRushActivityStatus, and return: ", res.body)
   
   local returnData = cjson.decode(res.body)
   
   if (returnData.errorCode == "00" and returnData.returnObject == "RUNNING") then
		ngx.timer.at(config["reservation_checking_frequency_seconds"], clearExpiredReservations, activityCode)
	end
end

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

res, err = red:get(args.activityCode .. "_running_status")

if res == ngx.null then
	local ok, err = ngx.timer.at(config["reservation_checking_frequency_seconds"], clearExpiredReservations, args.activityCode)
	res, err = red:set(args.activityCode .. "_running_status", "RUNNING")
else
	if res == "RUNNING" then
		returnResult["errorCode"] = "02"
		returnResult["errorMessage"] = "The checking job has already been started."
		ngx.say(cjson.encode(returnResult))
		return
	else
		local ok, err = ngx.timer.at(config["reservation_checking_frequency_seconds"], clearExpiredReservations, args.activityCode)
		res, err = red:set(args.activityCode .. "_running_status", "RUNNING")
	end
end

ngx.say(cjson.encode(returnResult))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
   -- ngx.say("failed to set keepalive: ", err)
	returnResult["errorCode"] = "04"
	returnResult["errorMessage"] = "failed to set keepalive: " .. err
   return
end

