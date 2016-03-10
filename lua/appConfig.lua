local _m = {}

_m["redis_host"] = "127.0.0.1"
_m["redis_port"] = 6379
_m["reservation_expire_seconds"] = 20
_m["reservation_checking_frequency_seconds"] = 5
_m["clear_expired_reservations_api_url"] = "http://127.0.0.1:6699/rushResources/clearExpiredReservations"
_m["get_rush_activity_status_api_url"] = "http://127.0.0.1:6699/rushResources/getRushActivityStatus"
return _m

