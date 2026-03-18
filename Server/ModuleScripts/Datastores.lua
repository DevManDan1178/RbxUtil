local DataStoreService = game:GetService("DataStoreService")

--Store datastores here
local Datastores : {}


--[[Requests a datastore to set a key, defaults to 3 max attempts]]
function Datastores.SetDatastore(orderedDataStore : OrderedDataStore, key : any, value : number, maxAttempts : number?) : boolean
	local success, attempt = false,0
	repeat
		success = pcall(function()
			orderedDataStore:SetAsync(key, value)
		end)
		attempt += 1
		if not success then 
			task.wait(0.1)
		end
	until success or attempt == maxAttempts or 3
	return success
end

--[[Queries a datastore for a key, defaults to 3 max attempts]]
function Datastores.GetFromDatastore(dataStore : GlobalDataStore, key : any, maxAttempts : number?) : any?
	local success, result, attempt = false, nil, 0
	repeat
		success, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		attempt += 1
		if not success then 
			task.wait()
		end
	until success or attempt == maxAttempts or 3
	return result, success
end

--[[Uses HTTPService:JSONDecode to decode data, if data is not string, returns it as is]]
function Datastores.DeserializeData(data : {}) : {} --or create a custom type
	if typeof(playerData) == "string" then
		return HTTPService:JSONDecode(playerData)
	else
		return playerData
	end
end
--[[Uses HTTPService:JSONEncode to encode data, if data is already string, returns it as is]]
function Datastores.SerializeData(data : {}) : string
	if typeof(data) ~= "string" then
		return HTTPService:JSONEncode(playerData)
	else
		return data
	end
end

return Datastores
