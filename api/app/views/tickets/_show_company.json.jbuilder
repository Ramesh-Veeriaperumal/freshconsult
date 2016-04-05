if @company
  json.set! :company do   
    json.cache! CacheLib.key(@company, params) do 
      json.extract! @company, :id, :name
    end
  end
else
  json.set! :company, {}
end
