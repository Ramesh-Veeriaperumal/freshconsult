json.requester do   
  json.cache! CacheLib.key(@requester, params) do
    json.extract! @requester, :email, :id, :mobile, :name, :phone
  end
end
