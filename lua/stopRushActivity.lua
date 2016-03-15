local redis = require "resty.redis"
local utils = require "lua.lib.utils"

local red = redis:new()

local config = require("lua.appConfig")

red:set_timeout(1000) -- 1 sec

local cjson = require "cjson.safe"

local ok, err = red:connect(config["redis_host"], config["redis_port"])
if not ok then
   ngx.say(cjson.encode(utils.getReturnResult("01","Failed to connect: " .. err )))
   return
end

local args

if (ngx.var.request_method == "POST") then
	ngx.req.read_body()
   args = ngx.req.get_post_args()
else
   args = ngx.req.get_uri_args()
end

-- parameter checking

if not args.activityCode then
	ngx.say(cjson.encode(utils.getReturnResult("02","No activityCode parameter.")))
   return
end

-- end of parameter checking

local res, err

res, err = red:get(args.activityCode .. "_running_status")

if res == ngx.null then
	ngx.say(cjson.encode(utils.getReturnResult("03","The checking job hasn't been started.")))
	return
else
	if res == "RUNNING" then
		res, err = red:set(args.activityCode .. "_running_status", "STOPPED")
	else
		ngx.say(cjson.encode(utils.getReturnResult("03","The checking job hasn't been started.")))
		return
	end
end

ngx.say(cjson.encode(utils.getReturnResult("00")))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
	ngx.say(cjson.encode(utils.getReturnResult("06","Failed to set keepalive: " .. err)))
   return
end

