module Fdadmin::ApiCallConstants
	
	HTTP_METHOD_TO_CLASS_MAPPING = {
  :get => Net::HTTP::Get,
  :post => Net::HTTP::Post,
  :put => Net::HTTP::Put,
  :delete => Net::HTTP::Delete,
  :patch => Net::HTTP::Patch
	}

	HTTP_METHOD_TO_SYMBOL_MAPPING = {
    "get" => :get,
    "post" => :post
  }

end