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

if not args.reservationTrackingId then
   ngx.say(cjson.encode(utils:getReturnResult("03","No reservationTrackingId parameter.")))
   return
end

-- end of parameter checking

local res, err

local reservation

reservation, err = red:get(args.activityCode .. "_reservation_" .. args.reservationTrackingId)

if reservation == ngx.null then
   ngx.say(cjson.encode(utils:getReturnResult("04","Can't find reservation trackingId, and please record this reservation info as EXCEPTION status and needs detailed checking by human beings.")))
   return
end

res, err = red:lrem(args.activityCode .. "_reservations", 0, reservation)

ngx.say(cjson.encode(utils:getReturnResult("00")))

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
	ngx.say(cjson.encode(utils:getReturnResult("06","Failed to set keepalive: " .. err)))
   return
end

