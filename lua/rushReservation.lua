local redis = require "resty.redis"
local utils = require "lua.lib.utils"

local red = redis:new()

local config = require("lua.appConfig")

local uuid = require("lua.lib.resty.uuid")

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

if not args.reservationData then
   ngx.say(cjson.encode(utils.getReturnResult("03","No reservationData parameter.")))
   return
end

local jsonObject = cjson.decode(args.reservationData)

if not jsonObject then
   ngx.say(cjson.encode(utils.getReturnResult("04","Parameter reservationData is not valid JSON format.")))
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
	ngx.say(cjson.encode(utils.getReturnResult("06","The activity's status is not RUNNING.")))
	return
end

-- end of checking

local reservations = {}
local hasSuccessfulReservations = false

for i,value in ipairs(jsonObject) do
	res, err = red:get(args.activityCode .. "_resource_" .. value.resourceCode)
	
	local redisReturn = utils.handleRedisReturns(res, err, "04")
	
	if redisReturn then
		ngx.say(cjson.encode(redisReturn))
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
	
	res, err = red:init_pipeline()

	res, err = red:rpush(args.activityCode .. "_reservations", jsonReservations)
	
	res, err = red:set(args.activityCode .. "_reservation_" .. trackingId, jsonReservations)
	
	-- expire after x seconds
	res, err = red:expire(args.activityCode .. "_reservation_" .. trackingId, config["reservation_expire_seconds"])
	
	res, err = red:commit_pipeline()

	ngx.say(cjson.encode(utils.getReturnResult("00", nil, reservations)))
else
	ngx.say(cjson.encode(utils.getReturnResult("05", "Can't reserve any resource.")))
end

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = red:set_keepalive(10000, 100)
if not ok then
	ngx.say(cjson.encode(utils.getReturnResult("06","Failed to set keepalive: " .. err)))
   return
end

