local redis = require "resty.redis"
local utils = require "lib.utils"

local red = redis:new()

local config = require("appConfig")

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

if not args.resourcesJsonData then
	ngx.say(cjson.encode(utils.getReturnResult("03","No resourcesJsonData parameter.")))
   return
end

local jsonObject = cjson.decode(args.resourcesJsonData)

if not jsonObject then
	ngx.say(cjson.encode(utils.getReturnResult("04","resourcesJsonData parameter is not valid JSON format.")))
   return
end

-- end of parameter checking

local res, err

for key, value in pairs(jsonObject) do
	res, err = red:set(args.activityCode .. "_resource_" .. key, value)

	local redisReturn = utils.handleRedisReturns(res, err, "05")
	
	if redisReturn then
		ngx.say(cjson.encode(redisReturn))
		return
	end
end


-- return back with success status
ngx.say(cjson.encode(utils.getReturnResult("00")))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
	ngx.say(cjson.encode(utils.getReturnResult("06","Failed to set keepalive: " .. err)))
   return
end

