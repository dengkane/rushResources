# rushResources (or 秒杀 in Chinese)

## Introduction:

The application would be difficult to implement if there are many users access it and rush for some very limited resources concurrently. I have considered many related issues and got a good solution, and implemented it as a standard API service. There are many scenarios to use this application, such as selling limited number of goods during a short time period and many buyers are interested in them, etc.

This application is implemented as HTTP Restful APIs, and use Redis as the storage layer. It can be run standalone, and you use it via APIs.

The whole process would be:

1. You load your resources data into this application by calling an HTTP API.

2. You start the resources reservation activity by calling an HTTP API.

3. Your application will call an HTTP API to reserve some resources.

4. Your application will call an HTTP API to confirm your reservations, or the reservations will be cancelled if you don't confirm them.

5. You can get the available quantity for a resource by calling an HTTP API, or get the available quantities for some resources by calling another HTTP API.

6. After the activity, you can call an HTTP API to end it.


## Requirements:

1. OpenResty has been installed under /usr/local/openresty, please refer to http://www.openresty.org/ for details.

2. Redis has been installed and without authentication settings.


## Usage:

1. Modify the Redis settings in lua/appConfig.lua, the defaults are localhost and 6379. There are several other settings too, and the setting names are easy to understand.

2. Start the app by running the shell file ./startup.sh, please modify the execution permission if it can't start. Please refer to OpenResty's documentation for how to start the service if you're using Windows to run OpenResty.

3. The APIs are :

 * Load resource data for an activity: *http://localhost:6699/rushResources/loadResources?activityCode=activity001&resourcesJsonData={"product_001":100,"product_002":50,"product_003":80}*, and you should use HTTP POST to access this API, and pass two parameters: activityCode and resourcesJsonData, activityCode is the unique code you define for your activity, and resourcesJsonData are the resources which have fixed quantities, every resource has a resource code, take the resource code as key, and the quantity as value, and all resources are formated as JSON.

 * Get the available quantity for a resource: *http://localhost:6699/rushResources/getResourceAvailableQuantity?activityCode=activity001&resourceCode=product_001*, and you can use HTTP GET/POST to access this API, and pass two parameters: activityCode and resourceCode, activityCode is the unique code you define for your activity, and resourceCode is the unique code for the resource.

 * Get available quantities for some resources: *http://localhost:6699/rushResources/getAllResourcesAvailableQuantities?activityCode=activity001&resourceCodes=["product_001","product_002"]*, and you should use HTTP POST to access this API, and pass two parameters: activityCode and resourceCodes, activityCode is the unique code you define for your activity, and resourceCodes is the codes for the resources, and they are formated as a JSON array.

 * Start an activity: *http://localhost:6699/rushResources/startRushActivity?activityCode=activity001*, and you can use HTTP GET/POST to access this API, and pass one parameter: activityCode, activityCode is the unique code you define for your activity.

 * Stop an activity: *http://localhost:6699/rushResources/stopRushActivity?activityCode=activity001*, and you can use HTTP GET/POST to access this API, and pass one parameter: activityCode, activityCode is the unique code you define for your activity.

 * Get the status of an activity: *http://localhost:6699/rushResources/getRushActivityStatus?activityCode=activity001*, and you can use HTTP GET/POST to access this API, and pass one parameter: activityCode, activityCode is the unique code you define for your activity.

 * Rush for some resources data for an activity: *http://localhost:6699/rushResources/loadResources?activityCode=activity001&resourcesJsonData={"product_001":100,"product_002":50,"product_003":80}*, and you should use HTTP POST to access this API, and pass two parameters: activityCode and resourcesJsonData, activityCode is the unique code you define for your activity, and resourcesJsonData are the resources which have fixed quantities, every resource has a resource code, take the resource code as key, and the quantity as value, and all resources are formated as JSON. This API will return a trackingId and you should store it in your application, and will use it in next reservation confirmation API.

 * Confirm a reservation: *http://localhost:6699/rushResources/confirmReservation?activityCode=activity001&reservationTrackingId=tracking_id_xxx*, and you can use HTTP GET/POST to access this API, and pass two parameters: activityCode and reservationTrackingId, activityCode is the unique code you define for your activity, and reservationTrackingId is the reservation trackingId which you get from previous API.


4. In your applications, you can use above URLs to access the API services, and remember that there are several APIs which need JSON format parameters, and you should use HTTP POST to pass the parameters.



