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

res, err = red:get(args.activityCode .. "_running_status")

if res == ngx.null then
	returnResult["errorCode"] = "02"
	returnResult["errorMessage"] = "The checking job hasn't been started."
	ngx.say(cjson.encode(returnResult))
	return
else
	if res == "RUNNING" then
		res, err = red:set(args.activityCode .. "_running_status", "STOPPED")
	else
		returnResult["errorCode"] = "02"
		returnResult["errorMessage"] = "The checking job hasn't been started."
		ngx.say(cjson.encode(returnResult))
		return
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

